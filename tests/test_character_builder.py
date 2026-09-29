from pathlib import Path
import sys
import hashlib
import json
import tempfile
import unittest
from unittest.mock import patch

TOOLS = Path(__file__).resolve().parents[1] / 'tools'
sys.path.insert(0, str(TOOLS))
import build_characters as converter
from build_character_cast import attachment_morphs


class CharacterBuilderTest(unittest.TestCase):
    def test_selected_originals_match_provenance(self):
        package = TOOLS.parent/'production/characters/cc0-2026-09-29'
        manifest = json.loads((package/'provenance.json').read_text())
        source = package/'source'
        self.assertEqual(set(manifest['files']), {str(p.relative_to(source)) for p in source.rglob('*') if p.is_file()})
        for path,record in manifest['files'].items():
            with self.subTest(path=path):
                content = (source/path).read_bytes()
                self.assertEqual(len(content), record['bytes'])
                self.assertEqual(hashlib.sha256(content).hexdigest(), record['sha256'])

    def test_attachment_textures_resolve_from_referenced_material(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root/'mesh').mkdir()
            (root/'materials').mkdir()
            (root/'mesh/eye.obj').write_text('v 0 0 0\n')
            (root/'materials/eye.mhmat').write_text('diffuseTexture iris.png\ntransparent True\n')
            path = root/'mesh/eye.mhclo'
            path.write_text('obj_file eye.obj\nmaterial ../materials/eye.mhmat\nverts 0\n0\n')
            with patch.object(converter, 'base', [(0,0,0)], create=True), patch.object(converter, 'weights', {0:{0:1.0}}, create=True):
                *_,material,directory = converter.clothing(path)
            self.assertEqual(directory.resolve(), (root/'materials').resolve())
            self.assertEqual(material['transparent'], 'True')
            self.assertEqual(material['diffuseTexture'], 'iris.png')

    def test_target_comments_and_sparse_vertices(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / 'face.target'
            path.write_text('# CC0\n\n7 .2 -.3 0\n15 0 1 2\n')
            self.assertEqual(converter.read_target(path), {7: (.2,-.3,0),15:(0,1,2)})

    def test_malformed_target_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / 'face.target'
            path.write_text('7 .2 3\n')
            with self.assertRaises(ValueError):
                converter.read_target(path)

    def test_attachment_uses_barycentric_displacements(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / 'lashes.mhclo'
            path.write_text('# CC0\nverts 0\n4\n1 2 3 .2 .3 .5 0 0 0\ndelete_verts\n100 - 200\n')
            morphs = {'blink': {4:(0,-1,0),1:(1,0,0),3:(0,0,2)}}
            result = attachment_morphs(path,morphs)['blink']
            self.assertEqual(len(result),2)
            self.assertEqual(result[0],(0,-1,0))
            self.assertEqual(result[1],(.2,0,1))

    def test_unaffected_attachment_has_zero_displacement(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / 'brows.mhclo'
            path.write_text('verts 0\n9\n')
            self.assertEqual(attachment_morphs(path,{'blink':{1:(1,0,0)}}),{'blink':{0:(0,0,0)}})


if __name__ == '__main__':
    unittest.main()
