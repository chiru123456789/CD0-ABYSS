import unittest

from controller_protocol import ControllerConfig, Mode
from waveform_adapter import (
    DAC_MIDPOINT, WaveformPlanError, build_waveform_plan,
    frequency_to_phase_word, scale_dac_sample,
)


class WaveformAdapterTests(unittest.TestCase):
    def test_cw_maps_frequency_to_dds_word(self):
        config = ControllerConfig(mode=Mode.CW, start_frequency_hz=25_000,
                                  amplitude_permille=500)
        plan = build_waveform_plan(config, 1_000_000)
        self.assertEqual(plan.start_word, frequency_to_phase_word(25_000, 1_000_000))
        self.assertEqual(plan.stop_word, plan.start_word)
        self.assertEqual(plan.step_word, 0)
        self.assertEqual(plan.sample_count, 0)
        self.assertAlmostEqual(plan.realized_start_hz, 25_000, delta=0.001)

    def test_lfm_maps_endpoints_and_sweep_rate(self):
        config = ControllerConfig(mode=Mode.LFM, start_frequency_hz=20_000,
                                  stop_frequency_hz=40_000,
                                  sweep_rate_hz_per_s=10_000,
                                  amplitude_permille=750)
        plan = build_waveform_plan(config, 1_000_000)
        self.assertEqual(plan.sample_count, 2001)
        self.assertGreater(plan.step_word, 0)
        self.assertAlmostEqual(plan.realized_start_hz, 20_000, delta=0.001)
        self.assertAlmostEqual(plan.realized_stop_hz, 40_000, delta=0.01)
        self.assertAlmostEqual(plan.duration_seconds, 0.002)

    def test_rejects_nyquist_and_sample_count_overflow(self):
        with self.assertRaises(WaveformPlanError):
            build_waveform_plan(ControllerConfig(start_frequency_hz=500_001), 1_000_000)
        config = ControllerConfig(mode=Mode.LFM, start_frequency_hz=1_000,
                                  stop_frequency_hz=2_000, sweep_rate_hz_per_s=1)
        with self.assertRaises(WaveformPlanError):
            build_waveform_plan(config, 1_000_000)

    def test_rejects_invalid_lfm_configuration(self):
        config = ControllerConfig(mode=Mode.LFM, start_frequency_hz=20_000,
                                  stop_frequency_hz=10_000, sweep_rate_hz_per_s=1000)
        with self.assertRaises(WaveformPlanError):
            build_waveform_plan(config, 1_000_000)

    def test_amplitude_scaling_about_midscale(self):
        self.assertEqual(scale_dac_sample(0, 0), DAC_MIDPOINT)
        self.assertEqual(scale_dac_sample(4095, 0), DAC_MIDPOINT)
        self.assertEqual(scale_dac_sample(0, 1000), 0)
        self.assertEqual(scale_dac_sample(4095, 1000), 4095)
        self.assertEqual(scale_dac_sample(4095, 500), 3072)
        self.assertEqual(scale_dac_sample(2048, 500), 2048)


if __name__ == "__main__":
    unittest.main(verbosity=2)
