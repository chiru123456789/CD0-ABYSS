# Sprint 03B — Controller to Waveform Adapter

**Status:** Host-side integration model; simulation only.

`sim/sprint03b/waveform_adapter.py` translates a validated `ControllerConfig` into parameters consumed by the existing DDS/LFM RTL concepts:

- 32-bit DDS phase tuning words: `round(frequency_hz * 2^32 / sample_rate_hz)`.
- CW uses one tuning word and no chirp step.
- LFM uses start/stop tuning words, an integer step word, and a uint16 sample counter.
- The adapter checks the Nyquist limit and rejects sweeps that cannot fit the RTL counter.
- `scale_dac_sample` models unsigned 12-bit offset-binary amplitude scaling around code 2048.

## LFM terminal-count alignment

The current `lfm_chirp_controller` increments its frequency word on an advance while more than one count remains. Its final advance deasserts `active` and asserts `done` without another frequency increment. Therefore the adapter sets `sample_count = intervals + 2`: this produces `intervals + 1` active frequency samples (including the start and stop endpoints), followed by the terminal advance. This behavior is covered by the adapter's duration and endpoint tests.

## Assumptions and limitations

- `sample_rate_hz` is an explicit simulation input, not a selected hardware clock or verified DAC update rate.
- The 12-bit DAC model is normalized code scaling only. No DAC part, reference voltage, output buffer, reconstruction filter, settling time, INL/DNL, or analogue load is selected or modeled.
- Amplitude permille is a digital scale factor, not a calibrated voltage or acoustic output level.
- Frequency conversion uses the existing 32-bit phase-accumulator convention. Realized frequencies can differ by tuning-word quantization.
- This Python adapter does not drive RTL pins or prove cycle-accurate MCU/FPGA integration. The next bench step is to feed captured RTL samples through a parameterized DAC/zero-order-hold model.

## Tests

Run from the repository root:

`python -m unittest discover -s sim/sprint03b -p 'test_*.py' -v`

The adapter tests cover CW conversion, LFM endpoints and duration, Nyquist/counter validation, invalid LFM settings, and amplitude scaling.
