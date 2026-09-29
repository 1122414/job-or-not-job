import array
import hashlib
import json
import math
from pathlib import Path
import unittest
import wave

ROOT = Path(__file__).resolve().parents[1]


class CityAudioAssetsTest(unittest.TestCase):
    def test_pinned_originals_and_derived_pcm(self):
        info = json.loads((ROOT / 'assets/audio/city/provenance.json').read_text())
        for row in info['originals']:
            path = ROOT / 'production/audio/cc0-2026-09-30' / row['file']
            self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(), row['sha256'])
            self.assertEqual(row['license'], 'CC0-1.0')
            self.assertTrue(row['page'].startswith('https://opengameart.org/content/'))
        for row in info['derived']:
            with self.subTest(file=row['file']):
                path = ROOT / row['file']
                self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(), row['sha256'])
                with wave.open(str(path)) as wav:
                    self.assertEqual((wav.getnchannels(), wav.getsampwidth(), wav.getframerate()), (1, 2, 44100))
                    pcm = wav.readframes(wav.getnframes())
                    self.assertEqual(hashlib.sha256(pcm).hexdigest(), row['pcm_sha256'])
                    values = array.array('h', pcm)
                    self.assertGreater(len(values), 4410)
                    self.assertLessEqual(max(abs(x) for x in values), 16384)
                    self.assertGreater(math.sqrt(sum(x*x for x in values)/len(values)), 30)
                    if row['loop']:
                        # The seam must not be a larger jump than the original waveform.
                        self.assertLessEqual(abs(values[-1]-values[0]), max(abs(a-b) for a, b in zip(values, values[1:])))
                    else:
                        self.assertEqual((values[0], values[-1]), (0, 0))


if __name__ == '__main__':
    unittest.main()
