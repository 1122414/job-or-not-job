from pathlib import Path
import hashlib
import json
import struct
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
from repair_character_skin import repair
from check_character_fitting import read_meshes


class CharacterSkinRepairTest(unittest.TestCase):
    def test_actual_legacy_models_repair_only_invalid_weight_rows(self):
        records = json.loads((ROOT / 'assets/characters/skin_repair_provenance.json').read_text())
        for name, expected in [('casual', 212), ('office', 245), ('office_female', 230)]:
            with self.subTest(name=name):
                record = records['characters'][name]
                path = ROOT / 'assets/characters' / (name + '.glb')
                current = path.read_bytes()
                original = bytearray(current)
                allowed = set()
                for row in record['rows']:
                    offset = row['offset']
                    original[offset:offset + 16] = bytes.fromhex(row['original_hex'])
                    allowed.update(range(offset, offset + 16))
                self.assertEqual(hashlib.sha256(original).hexdigest(), record['source_sha256'])
                result, metrics = repair(bytes(original))
                self.assertEqual(result, current)
                self.assertEqual(metrics['negative_values_removed'], expected)
                self.assertEqual(hashlib.sha256(result).hexdigest(), record['derived_sha256'])
                self.assertFalse({i for i, (a, b) in enumerate(zip(original, current)) if a != b} - allowed)
                self.assertEqual(repair(current), (current, {'negative_values_removed': 0, 'rows': []}))
                for mesh in read_meshes(path).values():
                    for weights in mesh['weights']:
                        self.assertGreaterEqual(min(weights), 0)
                        self.assertAlmostEqual(sum(weights), 1, places=5)

    def test_invalid_numeric_weights_are_rejected(self):
        records = json.loads((ROOT / 'assets/characters/skin_repair_provenance.json').read_text())
        raw = (ROOT / 'assets/characters/casual.glb').read_bytes()
        offset = records['characters']['casual']['rows'][0]['offset']
        for values in [(float('nan'), 0, 0, 0), (0, 0, 0, 0), (-1, -1, -1, -1)]:
            with self.subTest(values=values):
                bad = bytearray(raw)
                struct.pack_into('<4f', bad, offset, *values)
                with self.assertRaises(ValueError):
                    repair(bytes(bad))


if __name__ == '__main__':
    unittest.main()
