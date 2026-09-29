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
from build_character_cast import attachment_morphs, masked_attachment_vertices
from character_fitting import front_triangles, front_depth, bind_brows, contain_mouth, oral_faces, subdivide_attachment


class CharacterBuilderTest(unittest.TestCase):
    def test_subdivision_interpolates_skin_and_uv_without_mutating_source(self):
        vertices=[(0,0,0),(2,0,0),(0,2,0)]
        v,uv,faces,skin=subdivide_attachment(vertices,[(0,0),(1,0),(0,1)],
            [('body',[(0,0),(1,1),(2,2)])],[{0:1},{1:1},{0:1}])
        self.assertEqual(len(faces),4)
        self.assertEqual(v[3],(1,0,0))
        self.assertEqual(uv[3],(.5,0))
        self.assertEqual(skin[3],{0:.5,1:.5})
        self.assertEqual(len(vertices),3)

    def test_skin_weights_do_not_use_negative_geometry_extrapolation(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp)
            (root/'part.obj').write_text('v 0 0 0\n')
            path=root/'part.mhclo'
            path.write_text('obj_file part.obj\nverts 0\n0 1 2 1.2 -.3 .1 0 0 0\n')
            with patch.object(converter,'base',[(0,0,0),(1,0,0),(0,1,0)],create=True), patch.object(converter,'weights',{0:{0:1},1:{1:1},2:{2:1}},create=True):
                vertices,_,_,skin,*_=converter.clothing(path,positive_skin=True)
            self.assertEqual(vertices,[(-.3,.1,0)])  # Geometry extrapolation remains valid.
            self.assertEqual(skin,[{0:1.2,2:.1}])  # Convex skinning is normalized on export.

    def test_layer_mask_preserves_boundary_and_direct_reference(self):
        with tempfile.TemporaryDirectory() as tmp:
            path=Path(tmp)/'sock.mhclo'
            path.write_text('verts 0\n4\n1 2 3 .2 .3 .5 0 0 0\n4 2 3 1 0 0 0 0 0\n')
            self.assertEqual(masked_attachment_vertices(path,{1}),set())
            self.assertEqual(masked_attachment_vertices(path,{1,2}),{1})
            self.assertEqual(masked_attachment_vertices(path,{4}),{0,2})

    def test_brow_fit_follows_front_surface_with_clearance(self):
        vertices=[(-1,0,2),(1,0,2),(0,1,2)]
        faces=[('body',[(0,0),(1,0),(2,0)])]
        triangles=front_triangles(vertices,faces,0,1)
        self.assertAlmostEqual(front_depth((0,.5,-10),triangles),2)
        self.assertIsNone(front_depth((4,.5,0),triangles))
        self.assertEqual(front_triangles(vertices,[('body',[(2,0),(1,0),(0,0)])],0,1),[])
        self.assertEqual(bind_brows([(0,.5,1)],vertices,faces,{},.01)[0],[(0,.5,2.01)])

    def test_brow_binding_keeps_clearance_during_interpolated_face_motion(self):
        vertices=[(-1,0,2),(1,0,2),(0,1,2)]
        faces=[('body',[(0,0),(1,0),(2,0)])]
        delta={0:(.3,0,-.2),1:(.1,0,.2),2:(0,.1,.5)}
        fitted,shapes=bind_brows([(0,.5,1)],vertices,faces,{'raise':delta},.01)
        for weight in [0,.25,.5,.75,1]:
            body=[tuple(v[a]+weight*delta[i][a] for a in range(3)) for i,v in enumerate(vertices)]
            brow=tuple(fitted[0][a]+weight*shapes['raise'][0][a] for a in range(3))
            self.assertAlmostEqual(brow[2]-front_depth(brow,front_triangles(body,faces,0,2)),.01)

    def test_mouth_containment_preserves_opening_and_rim(self):
        vertices=[(-1,0,2),(1,0,2),(0,1,2),(0,.3,2.5),(4,.3,2.5)]
        outer=[('body',[(0,0),(1,0),(2,0)])]
        oral=[('body',[(0,0),(3,0),(4,0)])]
        fitted=contain_mouth(vertices,outer,oral,.01)
        self.assertEqual(fitted[0],vertices[0])
        self.assertAlmostEqual(fitted[3][2],1.99)
        self.assertEqual(fitted[4],vertices[4])

    def test_mouth_island_does_not_select_neighbouring_hand_uvs(self):
        uvs=[(.76,.87),(.92,.87),(.8,.98),(.7,.85),(.76,.9),(.762,.94),(.761,.97)]
        mouth=('body',[(0,0),(1,1),(2,2)])
        hand=[('body',[(3,3),(4,4),(5,5)]),('body',[(4,4),(6,6),(5,5)])]
        outer,oral=oral_faces([mouth]+hand,uvs)
        self.assertEqual(oral,[mouth])
        self.assertEqual(outer,hand)

    def test_mouth_containment_does_not_project_onto_far_side_of_head(self):
        vertices=[(-1,0,2),(1,0,2),(0,1,2),(0,.3,3)]
        outer=[('body',[(0,0),(1,0),(2,0)])]
        oral=[('body',[(0,0),(3,0),(1,0)])]
        self.assertEqual(contain_mouth(vertices,outer,oral,.01,.1),vertices)

    def test_deformed_normal_is_perpendicular_to_deformed_surface(self):
        normals=converter.vertex_normals([(0,0,0),(1,0,0),(0,1,1)],[[(0,0),(1,0),(2,0)]])
        for normal in normals:
            self.assertAlmostEqual(sum(n*n for n in normal),1)
            self.assertAlmostEqual(normal[0],0)
            self.assertAlmostEqual(normal[1]+normal[2],0)
            self.assertGreater(normal[2],0)

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
