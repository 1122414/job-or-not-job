"""Sample exported candidate brow/skin clearance, including interpolated morphs.

This is an hm08 frontal surface check, not general collision or animation acceptance.
Usage: python3 tools/check_character_fitting.py CANDIDATE_DIRECTORY REPORT_JSON
"""
import argparse
import hashlib
import json
import struct
from pathlib import Path
from character_fitting import front_triangles, front_depth


def read_meshes(path):
    raw=path.read_bytes()
    length,kind=struct.unpack_from('<II',raw,12)
    assert kind==0x4e4f534a
    doc=json.loads(raw[20:20+length])
    binary=20+length+8
    def accessor(index):
        item=doc['accessors'][index]
        view=doc['bufferViews'][item['bufferView']]
        fmt={5126:'f',5125:'I',5123:'H'}[item['componentType']]
        width={'VEC3':3,'VEC4':4,'SCALAR':1}[item['type']]
        size=struct.calcsize('<'+fmt*width)
        start=binary+view.get('byteOffset',0)+item.get('byteOffset',0)
        return [struct.unpack_from('<'+fmt*width,raw,start+i*view.get('byteStride',size)) for i in range(item['count'])]
    meshes={}
    for mesh in doc['meshes']:
        primitive=mesh['primitives'][0]
        ids=[v[0] for v in accessor(primitive['indices'])]
        meshes[mesh['name']]={
            'positions':accessor(primitive['attributes']['POSITION']),
            'faces':[('',[(v,0) for v in ids[i:i+3]]) for i in range(0,len(ids),3)],
            'weights':accessor(primitive['attributes']['WEIGHTS_0']),
            'morphs':{name:accessor(target['POSITION']) for name,target in zip(mesh.get('extras',{}).get('targetNames',[]),primitive.get('targets',[]))}}
    return meshes


def pose(mesh,values):
    return [tuple(v[a]+sum(weight*mesh['morphs'][name][i][a] for name,weight in values.items()) for a in range(3)) for i,v in enumerate(mesh['positions'])]


def inspect(path,recipe):
    meshes=read_meshes(path)
    body=meshes['body']; brows=meshes[recipe['eyebrows']]
    poses=[{}]+[{name:i/10} for name in body['morphs'] for i in range(1,11)]
    poses += [{'mouth_open':.6,'brow_raise':.7},{'blink':.5,'brow_lower':.7}]
    samples=[]
    for values in poses:
        vertices=pose(brows,values)
        # Vertices alone miss intersections in the middle of a large triangle.
        points=list(vertices)
        for group,face in brows['faces']:
            triangle=[vertices[i] for i,uv in face]
            points.append(tuple(sum(v[a] for v in triangle)/3 for a in range(3)))
            for i in range(3): points.append(tuple((triangle[i][a]+triangle[(i+1)%3][a])/2 for a in range(3)))
        triangles=front_triangles(pose(body,values),body['faces'],min(v[1] for v in points),max(v[1] for v in points))
        depths=[front_depth(p,triangles) for p in points]
        gaps=[(p[2]-z)*1000 for p,z in zip(points,depths) if z is not None]
        samples.append({'weights':values,'samples':len(points),'unmapped':sum(z is None for z in depths),
                        'penetrations':sum(g<-.01 for g in gaps),'minimum_clearance_mm':min(gaps)})
    negative=sum(w<0 for mesh in meshes.values() for weights in mesh['weights'] for w in weights)
    oral=meshes.get('mouth_interior')
    bounds=None if oral is None else {'min':[min(v[a] for v in oral['positions']) for a in range(3)],
                                     'max':[max(v[a] for v in oral['positions']) for a in range(3)]}
    return {'id':recipe['id'],'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),
            'negative_exported_skin_weights':negative,'oral_bounds_m':bounds,'brow_samples':samples}


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('candidates',type=Path)
    parser.add_argument('report',type=Path)
    args=parser.parse_args()
    manifest=json.loads((args.candidates/'candidates.json').read_text())
    records=[inspect(args.candidates/(person['id']+'.glb'),person['recipe']) for person in manifest['characters']]
    failures=sum(person['negative_exported_skin_weights']+sum(s['penetrations']+s['unmapped'] for s in person['brow_samples']) for person in records)
    args.report.write_text(json.dumps({'scope':'43 frontal morph states; brow vertices, edge midpoints and centroids; no skeletal poses',
                                      'characters':records,'failures':failures},indent=2)+'\n')
    for person in records:
        print(person['id'],'negative weights',person['negative_exported_skin_weights'],'minimum brow clearance mm',min(s['minimum_clearance_mm'] for s in person['brow_samples']))
    raise SystemExit(1 if failures else 0)
