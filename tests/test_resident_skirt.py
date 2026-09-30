from pathlib import Path
import hashlib
import json
import struct
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools'))
import prepare_resident_skirt as recipe


class ResidentSkirtTest(unittest.TestCase):
    def test_rebuild_preserves_geometry_and_valid_non_skirt_data(self):
        original = recipe.SOURCE.read_bytes()
        result, metrics = recipe.prepare(original)
        self.assertEqual(result, recipe.TARGET.read_bytes())
        self.assertEqual(len(original), len(result))
        self.assertEqual(metrics['changed_exported_vertices'], 420)
        length = struct.unpack_from('<I', original, 12)[0]
        doc = json.loads(original[20:20 + length])
        primitive = next(mesh for mesh in doc['meshes']
                         if mesh['name'] == 'female_elegantsuit01')['primitives'][0]
        allowed = set()
        for attribute, size in [('JOINTS_0', 8), ('WEIGHTS_0', 16)]:
            accessor = doc['accessors'][primitive['attributes'][attribute]]
            view = doc['bufferViews'][accessor['bufferView']]
            start = 28 + length + view.get('byteOffset', 0) + accessor.get('byteOffset', 0)
            for i in range(accessor['count']):
                offset = start + i * view.get('byteStride', size)
                allowed.update(range(offset, offset + size))
        changes = {i for i, (a, b) in enumerate(zip(original, result)) if a != b}
        self.assertEqual(metrics['skin_repair']['negative_values_removed'], 230)
        for row in metrics['skin_repair']['rows']:
            allowed.update(range(row['offset'], row['offset'] + 16))
        self.assertTrue(changes)
        self.assertFalse(changes - allowed)
        record = json.loads(recipe.RECORD.read_text())
        self.assertEqual(hashlib.sha256(original).hexdigest(), record['source_sha256'])
        self.assertEqual(hashlib.sha256(result).hexdigest(), record['derived_sha256'])

    def test_independently_modified_source_is_rejected(self):
        changed = bytearray(recipe.SOURCE.read_bytes())
        changed[-1] ^= 1
        with self.assertRaisesRegex(ValueError, 'source differs'):
            recipe.prepare(changed)


if __name__ == '__main__':
    unittest.main()
