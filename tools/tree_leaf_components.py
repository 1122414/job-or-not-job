"""Group source foliage islands without dropping leaves during mesh reduction.

Standard-library production step. This file is not used by the game. The binary
mapping is consumed by bake_city_tree.gd against the same verified glTF source.
"""
import argparse
from array import array
from collections import defaultdict
import hashlib
import json
from pathlib import Path
import struct
import sys

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'production/environment/polyhaven_nature/tree_small_02'


def components(indices, vertex_count):
    if vertex_count <= 0 or not indices or len(indices) % 3:
        raise ValueError('Foliage requires vertices and complete triangles')
    if min(indices) < 0 or max(indices) >= vertex_count:
        raise ValueError('Foliage triangle references an invalid vertex')
    parent = array('I', range(vertex_count))

    def find(value):
        while parent[value] != value:
            parent[value] = parent[parent[value]]
            value = parent[value]
        return value

    for i in range(0, len(indices), 3):
        a, b, c = (find(indices[i + j]) for j in range(3))
        parent[b] = a
        parent[c] = a
    groups = defaultdict(list)
    for vertex in range(vertex_count):
        groups[find(vertex)].append(vertex)
    return list(groups.values())


def bake(output):
    provenance = json.loads((SOURCE.parent / 'provenance.json').read_text())
    records = next(a['files'] for a in provenance['assets'] if a['id'] == SOURCE.name)
    for name in ('tree_small_02_2k.gltf', 'tree_small_02.bin'):
        if hashlib.sha256((SOURCE / name).read_bytes()).hexdigest() != records[name]['sha256']:
            raise ValueError('Source changed; review before baking: ' + name)
    data = json.loads((SOURCE / 'tree_small_02_2k.gltf').read_text())
    primitive = data['meshes'][0]['primitives'][1]
    accessor = data['accessors'][primitive['indices']]
    view = data['bufferViews'][accessor['bufferView']]
    if accessor['componentType'] != 5125 or view.get('byteStride', 4) != 4:
        raise ValueError('Reviewed leaf index layout changed')
    start = view.get('byteOffset', 0) + accessor.get('byteOffset', 0)
    indices = array('I')
    indices.frombytes((SOURCE / 'tree_small_02.bin').read_bytes()[start:start + accessor['count'] * 4])
    if sys.byteorder != 'little':
        indices.byteswap()
    vertex_count = data['accessors'][primitive['attributes']['POSITION']]['count']
    groups = components(indices, vertex_count)
    output.parent.mkdir(parents=True, exist_ok=True)
    with output.open('wb') as stream:
        stream.write(b'TREEISL1')
        stream.write(struct.pack('<II', vertex_count, len(groups)))
        for group in groups:
            stream.write(struct.pack('<I', len(group)))
            stream.write(struct.pack('<' + str(len(group)) + 'I', *group))
    output.with_suffix('.manifest.json').write_text(json.dumps({
        'source_files': {name: records[name]['sha256'] for name in
                         ('tree_small_02_2k.gltf', 'tree_small_02.bin')},
        'mapping_sha256': hashlib.sha256(output.read_bytes()).hexdigest(),
        'vertices': vertex_count, 'islands': len(groups),
    }, indent=2) + '\n')
    print('TREE_COMPONENTS', json.dumps({'vertices': vertex_count, 'islands': len(groups),
                                        'triangles': len(indices) // 3, 'bytes': output.stat().st_size}))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, default=ROOT / 'build/c4d-asset-review/leaf-components.bin')
    bake(parser.parse_args().output)
