import unittest
import numpy as np
from waveforms import waveforms, spectrum, FS

class TestWaveforms(unittest.TestCase):
    def test_families_are_bounded_and_distinct(self):
        t, waves = waveforms()
        self.assertEqual(len(waves), 4)
        for x in waves.values():
            self.assertEqual(len(t), len(x))
            self.assertTrue(np.isfinite(x).all())
            self.assertLessEqual(np.max(np.abs(x)), 1.0000001)
        self.assertFalse(np.array_equal(waves['CW'], waves['LFM']))
        self.assertFalse(np.array_equal(waves['LFM'], waves['Geometric']))
    def test_spectrum(self):
        _, waves = waveforms()
        f, mag = spectrum(waves['CW'])
        self.assertEqual(f.shape, mag.shape)
        self.assertEqual(f[0], 0)
        self.assertLessEqual(f[-1], FS/2)
    def test_aliasing_rejected(self):
        with self.assertRaises(ValueError):
            waveforms(fs=10_000, f1=20_000)

if __name__ == '__main__':
    unittest.main()
