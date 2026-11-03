"""ClockDomain Zero: reproducible reference sonar waveforms (simulation only)."""
import numpy as np

FS = 200_000  # provisional simulation rate, not hardware promise
DURATION = 0.010
F0 = 8_000.0
F1 = 20_000.0


def waveforms(fs=FS, duration=DURATION, f0=F0, f1=F1):
    if fs <= 2 * max(f0, f1) or duration <= 0 or f0 <= 0 or f1 <= 0:
        raise ValueError('Require positive frequencies, duration, and fs > 2*max frequency')
    n = int(round(fs * duration))
    if n < 8:
        raise ValueError('Need at least 8 samples')
    t = np.arange(n) / fs
    # Digital phase integration, consistent with a digital DDS frequency-word approach.
    f_lfm = f0 + (f1 - f0) * t / duration
    ratio = f1 / f0
    f_geo = f0 * ratio ** (t / duration)
    p_cw = 2 * np.pi * np.cumsum(np.full(n, f0)) / fs
    p_lfm = 2 * np.pi * np.cumsum(f_lfm) / fs
    p_geo = 2 * np.pi * np.cumsum(f_geo) / fs
    chips = np.array([1, 1, 1, -1, -1, 1, -1], dtype=int)
    chip_index = np.minimum((t / duration * len(chips)).astype(int), len(chips) - 1)
    bpsk = np.sin(p_cw) * chips[chip_index]
    # Raised-cosine on/off edges reduce abrupt pulse artifacts.
    ramp_len = max(1, n // 20)
    envelope = np.ones(n)
    u = (np.arange(ramp_len) + 1) / (ramp_len + 1)
    ramp = 0.5 - 0.5 * np.cos(np.pi * u)
    envelope[:ramp_len] = ramp
    envelope[-ramp_len:] = ramp[::-1]
    return t, {'CW': np.sin(p_cw) * envelope,
               'LFM': np.sin(p_lfm) * envelope,
               'Geometric': np.sin(p_geo) * envelope,
               'BPSK': bpsk * envelope}


def spectrum(signal, fs=FS):
    win = np.hanning(len(signal))
    frequencies = np.fft.rfftfreq(len(signal), 1 / fs)
    magnitude = np.abs(np.fft.rfft(signal * win))
    db = 20 * np.log10(np.maximum(magnitude / max(magnitude.max(), 1e-12), 1e-12))
    return frequencies, db


if __name__ == '__main__':
    from pathlib import Path
    import matplotlib
    matplotlib.use('Agg')
    import matplotlib.pyplot as plt
    t, waves = waveforms()
    out = Path(__file__).resolve().parent.parent / 'plots'
    out.mkdir(exist_ok=True)
    for name, samples in waves.items():
        hz, mag = spectrum(samples)
        fig, axes = plt.subplots(2, 1, figsize=(9, 6))
        axes[0].plot(t * 1000, samples)
        axes[0].set(xlabel='Time (ms)', ylabel='Normalized amplitude', title=f'{name} pulse (simulated)')
        axes[1].plot(hz / 1000, mag)
        axes[1].set(xlabel='Frequency (kHz)', ylabel='Relative magnitude (dB)', ylim=(-95, 5))
        fig.tight_layout()
        fig.savefig(out / f'{name.lower()}_analysis.png', dpi=135)
        plt.close(fig)
    print(f'Generated {len(waves)} simulated waveform plots in {out}')
