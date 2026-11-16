"""Translate validated controller settings into DDS/LFM RTL parameters.

This is a host-side integration model. It does not emulate a DAC, MCU peripheral,
FPGA timing, or the analogue/acoustic chain.
"""
from __future__ import annotations

from dataclasses import dataclass

from controller_protocol import ControllerConfig, Mode

PHASE_MODULUS = 1 << 32
DAC_MAX = (1 << 12) - 1
DAC_MIDPOINT = 1 << 11


class WaveformPlanError(ValueError):
    """Raised when controller settings cannot be represented by the RTL."""


@dataclass(frozen=True)
class WaveformPlan:
    mode: Mode
    sample_rate_hz: int
    start_word: int
    stop_word: int
    step_word: int
    sample_count: int
    amplitude_permille: int
    realized_start_hz: float
    realized_stop_hz: float

    @property
    def duration_seconds(self) -> float:
        return (self.sample_count - 2) / self.sample_rate_hz if self.mode == Mode.LFM else 0.0


def frequency_to_phase_word(frequency_hz: int, sample_rate_hz: int) -> int:
    """Convert output frequency to a 32-bit DDS tuning word."""
    if sample_rate_hz <= 0:
        raise WaveformPlanError("sample rate must be positive")
    if not 0 < frequency_hz <= sample_rate_hz / 2:
        raise WaveformPlanError("frequency must be above 0 Hz and at or below Nyquist")
    return round(frequency_hz * PHASE_MODULUS / sample_rate_hz)


def build_waveform_plan(config: ControllerConfig, sample_rate_hz: int) -> WaveformPlan:
    """Build parameters for dds_phase_core or lfm_wavecore.

    For LFM, sample_count is intervals + 2: the RTL emits intervals + 1 active
    samples including both endpoints, then consumes one final advance to assert done.
    The integer step word is
    rounded to the nearest representable increment, so realized_stop_hz can
    differ slightly from the requested stop frequency.
    """
    if sample_rate_hz <= 0:
        raise WaveformPlanError("sample rate must be positive")
    if not 0 <= config.amplitude_permille <= 1000:
        raise WaveformPlanError("amplitude must be in range 0..1000 permille")

    start_word = frequency_to_phase_word(config.start_frequency_hz, sample_rate_hz)
    if config.mode == Mode.CW:
        realized = start_word * sample_rate_hz / PHASE_MODULUS
        return WaveformPlan(
            Mode.CW, sample_rate_hz, start_word, start_word, 0, 0,
            config.amplitude_permille, realized, realized,
        )

    if config.mode != Mode.LFM:
        raise WaveformPlanError("unsupported waveform mode")
    if config.stop_frequency_hz <= config.start_frequency_hz:
        raise WaveformPlanError("LFM stop frequency must exceed start frequency")
    if config.stop_frequency_hz > sample_rate_hz / 2:
        raise WaveformPlanError("LFM stop frequency exceeds Nyquist")
    if config.sweep_rate_hz_per_s <= 0:
        raise WaveformPlanError("LFM sweep rate must be positive")

    stop_word = frequency_to_phase_word(config.stop_frequency_hz, sample_rate_hz)
    span_hz = config.stop_frequency_hz - config.start_frequency_hz
    intervals = round(span_hz * sample_rate_hz / config.sweep_rate_hz_per_s)
    if intervals < 1:
        raise WaveformPlanError("requested sweep is shorter than one sample interval")
    sample_count = intervals + 2
    if not 1 <= sample_count <= 0xFFFF:
        raise WaveformPlanError("LFM sample count does not fit the RTL uint16 input")
    step_word = round((stop_word - start_word) / intervals)
    if not 0 <= step_word <= 0xFFFFFFFF:
        raise WaveformPlanError("LFM step word does not fit uint32")

    realized_stop_word = start_word + step_word * intervals
    return WaveformPlan(
        Mode.LFM, sample_rate_hz, start_word, stop_word, step_word,
        sample_count, config.amplitude_permille,
        start_word * sample_rate_hz / PHASE_MODULUS,
        realized_stop_word * sample_rate_hz / PHASE_MODULUS,
    )


def scale_dac_sample(sample: int, amplitude_permille: int) -> int:
    """Scale an unsigned 12-bit offset-binary sine sample around midscale."""
    if not 0 <= sample <= DAC_MAX:
        raise ValueError("sample must be a 12-bit unsigned value")
    if not 0 <= amplitude_permille <= 1000:
        raise ValueError("amplitude must be in range 0..1000 permille")
    centered = sample - DAC_MIDPOINT
    scaled = round(centered * amplitude_permille / 1000)
    return min(DAC_MAX, max(0, DAC_MIDPOINT + scaled))
