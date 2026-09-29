"""Build review candidates from explicit CC0 character recipes; no runtime replacement.

python3 tools/build_character_cast.py SOURCE_DIRECTORY RECIPES_JSON OUTPUT_DIRECTORY
The source directory must contain base.obj, rig files, selected assets and targets/.
"""
import argparse
import hashlib
import json
from pathlib import Path
import build_characters as converter


def attachment_morphs(path, morphs):
    """Carry facial displacements through the original barycentric attachment mapping."""
    mapping = []
    in_vertices = False
    for line in path.read_text().splitlines():
        fields = line.split()
        if not fields or fields[0].startswith('#'):
            continue
        if fields[0] == 'verts':
            in_vertices = True
            continue
        if fields[0] == 'delete_verts':
            break
        if not in_vertices or not fields[0].lstrip('-').isdigit():
            continue
        if len(fields) == 1:
            mapping.append(([int(fields[0])], [1.0]))
        else:
            mapping.append((list(map(int, fields[:3])), list(map(float, fields[3:6]))))
    return {name: {vertex: tuple(sum(values.get(i, (0,0,0))[axis]*w for i,w in zip(ids,weights))
                                 for axis in range(3))
                   for vertex,(ids,weights) in enumerate(mapping)}
            for name,values in morphs.items()}


def build(source, recipes, output):
    output.mkdir(parents=True, exist_ok=True)
    profiles = json.loads(recipes.read_text())
    records = []
    for profile in profiles['characters']:
        converter.configure(source, {source/'targets'/name: weight for name,weight in profile['shape'].items()}, profile['scale'])
        model = converter.GLTF()
        parts = []
        hidden = set()
        for name in [profile['outfit'], profile['shoes'], profile['hair'], profile['eyebrows'], profile['eyelashes']]:
            path = converter.find(name+'.mhclo')
            item = converter.clothing(path)
            hidden.update(item[4])
            parts.append((name, path, item))
        expressions = {}
        for name, sources in profiles['expressions'].items():
            delta = {}
            for target in sources:
                for vertex, movement in converter.read_target(source/'targets'/target).items():
                    old = delta.get(vertex, (0,0,0))
                    delta[vertex] = tuple(old[axis]+movement[axis] for axis in range(3))
            expressions[name] = delta
        body = [(group,face) for group,face in converter.base_faces if group == 'body']
        skin = model.material('skin', converter.find(profile['skin']), roughness=0.6)
        model.mesh('body', converter.base, converter.base_uv, body, converter.weights, skin, hidden, expressions)
        for name, path, (vertices,uvs,faces,weights,deleted,material,directory) in parts:
            facial = name in [profile['eyebrows'], profile['eyelashes']]
            alpha = facial or name == profile['hair']
            texture = directory/material['diffuseTexture'] if 'diffuseTexture' in material else None
            color = profile['hair_color'] if name == profile['hair'] or facial else profile['clothing_color'] if name == profile['outfit'] else [1,1,1,1]
            mat = model.material(name, texture, color=color, alpha=alpha, roughness=0.65 if alpha else 0.8,
                                 normal=directory/material['normalmapTexture'] if material.get('normalmapTexture') else None,
                                 occlusion=directory/material['aomapTexture'] if material.get('aomapTexture') else None)
            model.mesh(name, vertices,uvs,faces,weights,mat, morphs=attachment_morphs(path, expressions) if facial else None)
        eye_path = converter.find('high-poly.mhclo')
        vertices,uvs,faces,_,_,material,directory = converter.clothing(eye_path)
        eye_weights = [{converter.index['eye.L' if vertex[0]>0 else 'eye.R']:1.0} for vertex in vertices]
        # The outer eye shell uses texture alpha; opaque export hides the iris.
        eye_material = model.material('eyes',directory/material['diffuseTexture'],
                                      alpha=material.get('transparent')=='True',roughness=0.18)
        model.mesh('eyes',vertices,uvs,faces,eye_weights,eye_material)
        target = output/(profile['id']+'.glb')
        model.save(target)
        records.append({'id':profile['id'],'sha256':hashlib.sha256(target.read_bytes()).hexdigest(),
                        'bytes':target.stat().st_size,'bones':len(converter.names),
                        'triangles':sum(model.doc['accessors'][mesh['primitives'][0]['indices']]['count']//3 for mesh in model.doc['meshes']),
                        'materials':len(model.doc['materials']),'expressions':list(expressions),
                        'height_m':max(converter.convert(converter.base[i])[1] for _,face in body for i,_ in face),
                        'recipe':profile})
        print(profile['id'],records[-1]['triangles'],'triangles',target.stat().st_size,'bytes')
    (output/'candidates.json').write_text(json.dumps({'status':'review_candidates_not_accepted','recipes_sha256':hashlib.sha256(recipes.read_bytes()).hexdigest(),'characters':records},ensure_ascii=False,indent=2)+'\n')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source',type=Path)
    parser.add_argument('recipes',type=Path)
    parser.add_argument('output',type=Path)
    args = parser.parse_args()
    build(args.source,args.recipes,args.output)
