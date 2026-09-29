"""Build review candidates from explicit CC0 character recipes; no runtime replacement.

python3 tools/build_character_cast.py SOURCE_DIRECTORY RECIPES_JSON OUTPUT_DIRECTORY
The source directory must contain base.obj, rig files, selected assets and targets/.
"""
import argparse
import hashlib
import json
from pathlib import Path
import build_characters as converter
from character_fitting import contain_mouth, oral_faces, bind_brows, displace, difference, subdivide_attachment


def attachment_mapping(path):
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
    return mapping


def attachment_morphs(path, morphs):
    """Carry facial displacements through the original barycentric attachment mapping."""
    mapping=attachment_mapping(path)
    return {name: {vertex: tuple(sum(values.get(i, (0,0,0))[axis]*w for i,w in zip(ids,weights))
                                 for axis in range(3))
                   for vertex,(ids,weights) in enumerate(mapping)}
            for name,values in morphs.items()}


def clothing_layer(path):
    for line in path.read_text().splitlines():
        fields=line.split()
        if fields and fields[0]=='z_depth': return int(fields[1])
    return 0


def masked_attachment_vertices(path, hidden):
    masked=set()
    for vertex,(indices,weights) in enumerate(attachment_mapping(path)):
        references=indices[:1] if not any(weights[1:]) else indices
        if sum(i in hidden for i in references)>len(references)//2:
            masked.add(vertex)
    return masked


def facial_shapes(source, profiles, body):
    outer,oral=oral_faces(body,converter.base_uv)
    original=list(converter.base)
    rest=contain_mouth(original,outer,oral,0.0015/converter.scale,0.01/converter.scale)
    expressions={}
    for name, sources in profiles['expressions'].items():
        delta={}
        for target in sources:
            for vertex,movement in converter.read_target(source/'targets'/target).items():
                old=delta.get(vertex,(0,0,0))
                delta[vertex]=tuple(old[axis]+movement[axis] for axis in range(3))
        shape=contain_mouth(displace(original,delta),outer,oral,0.0015/converter.scale,0.01/converter.scale)
        expressions[name]=difference(shape,rest)
    converter.base=rest
    return expressions,outer,oral


def build(source, recipes, output):
    output.mkdir(parents=True, exist_ok=True)
    profiles = json.loads(recipes.read_text())
    records = []
    for profile in profiles['characters']:
        converter.configure(source, {source/'targets'/name: weight for name,weight in profile['shape'].items()}, profile['scale'])
        model = converter.GLTF()
        body = [(group,face) for group,face in converter.base_faces if group == 'body']
        expressions,outer,oral=facial_shapes(source,profiles,body)
        parts = []
        hidden = set()
        for name in [profile['outfit'], profile['shoes'], profile['hair'], profile['eyebrows'], profile['eyelashes'],'teeth_base','tongue01']:
            path = converter.find(name+'.mhclo')
            item = converter.clothing(path,positive_skin=True)
            hidden.update(item[4])
            parts.append((name, path, item))
        skin = model.material('skin', converter.find(profile['skin']), roughness=0.6,double_sided=False)
        visible=[(g,f) for g,f in outer if not all(i in hidden for i,u in f)]
        model.mesh('body', converter.base, converter.base_uv, visible, converter.weights, skin, morphs=expressions)
        cavity=model.material('mouth_interior',converter.find(profile['skin']),color=(.32,.22,.22,1),roughness=.8,double_sided=False)
        model.mesh('mouth_interior',converter.base,converter.base_uv,oral,converter.weights,cavity,morphs=expressions)
        coverage={}
        for name, path, (vertices,uvs,faces,weights,deleted,material,directory) in parts:
            facial = name in [profile['eyebrows'], profile['eyelashes']]
            alpha = facial or name == profile['hair']
            texture = directory/material['diffuseTexture'] if 'diffuseTexture' in material else None
            color = profile['hair_color'] if name == profile['hair'] or facial else profile['clothing_color'] if name == profile['outfit'] else [1,1,1,1]
            mat = model.material(name, texture, color=color, alpha=alpha, roughness=0.65 if alpha else 0.8,
                                 normal=directory/material['normalmapTexture'] if material.get('normalmapTexture') else None,
                                 occlusion=directory/material['aomapTexture'] if material.get('aomapTexture') else None,
                                 double_sided=material.get('backfaceCull','False')!='True')
            morphs=attachment_morphs(path,expressions) if facial or name in ['teeth_base','tongue01'] else None
            if name==profile['eyebrows']:
                vertices,uvs,faces,weights=subdivide_attachment(vertices,uvs,faces,weights)
                vertices,morphs=bind_brows(vertices,converter.base,outer,expressions,0.0008/converter.scale)
            if name in [profile['outfit'],profile['shoes']]:
                covered=set().union(*(item[4] for other,other_path,item in parts if other in [profile['outfit'],profile['shoes']] and clothing_layer(other_path)>clothing_layer(path)))
                mask=masked_attachment_vertices(path,covered)
                filtered=[(g,f) for g,f in faces if not all(i in mask for i,u in f)]
                coverage[name]=len(faces)-len(filtered)
                faces=filtered
            model.mesh(name, vertices,uvs,faces,weights,mat, morphs=morphs)
        eye_path = converter.find('high-poly.mhclo')
        vertices,uvs,faces,_,_,material,directory = converter.clothing(eye_path,positive_skin=True)
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
                        'covered_triangles_removed':coverage,
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
