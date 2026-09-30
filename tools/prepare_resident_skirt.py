"""Apply the existing fitted-skirt recipe to the legacy resident outfit only.

Read the preserved project GLB, retain all geometry/material/bone data byte for
byte, and change only the skirt's JOINTS_0/WEIGHTS_0 values. No external tools.
"""
import hashlib
import json
from pathlib import Path
import struct

from character_fitting import skirt_weights

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'production/characters/resident-skirt-2026-09-30/office_female.glb'
ORIGINAL_SHA = '5769e05c92036a83dbf07f53e535272880d6ecb8e3333a24ec27a49a1b6b97de'
TARGET = ROOT / 'assets/characters/office_female.glb'
RECORD = ROOT / 'assets/characters/resident_skirt_provenance.json'


def prepare(content):
    if hashlib.sha256(content).hexdigest() != ORIGINAL_SHA:
        raise ValueError('Resident source differs from the reviewed project GLB')
    length, kind = struct.unpack_from('<II', content, 12)
    if kind != 0x4e4f534a:
        raise ValueError('Expected GLB JSON chunk')
    doc = json.loads(content[20:20 + length])
    binary_start = 20 + length + 8
    output = bytearray(content)
    modified = set()

    def accessor(index):
        entry = doc['accessors'][index]
        view = doc['bufferViews'][entry['bufferView']]
        code = {5126: 'f', 5123: 'H', 5125: 'I'}[entry['componentType']]
        size = {'SCALAR': 1, 'VEC3': 3, 'VEC4': 4, 'MAT4': 16}[entry['type']]
        fmt = '<' + code * size
        stride = view.get('byteStride', struct.calcsize(fmt))
        start = binary_start + view.get('byteOffset', 0) + entry.get('byteOffset', 0)
        return [struct.unpack_from(fmt, content, start + i * stride) for i in range(entry['count'])], (start, stride, fmt)

    skin = doc['skins'][0]
    bones = {doc['nodes'][node]['name']: i for i, node in enumerate(skin['joints'])}
    inverse, _ = accessor(skin['inverseBindMatrices'])
    rest = inverse[bones['upperleg01.L']]
    if any(abs(rest[i] - 1) > 1e-6 for i in (0, 5, 10, 15)):
        raise ValueError('Recipe requires the original translation-only rest rig')
    hip_height = -rest[13]
    mesh = next(m for m in doc['meshes'] if m['name'] == 'female_elegantsuit01')
    primitive = mesh['primitives'][0]
    attributes = primitive['attributes']
    vertices, _ = accessor(attributes['POSITION'])
    joints, joint_layout = accessor(attributes['JOINTS_0'])
    weights, weight_layout = accessor(attributes['WEIGHTS_0'])
    indices, _ = accessor(primitive['indices'])
    # glTF UV seams duplicate vertices. Weld positions for component discovery;
    # keep the original exported vertices and UVs in the final model.
    lookup, canonical, exported, original_weights = {}, [], [], []
    for i, position in enumerate(vertices):
        if position not in lookup:
            lookup[position] = len(canonical)
            canonical.append(position)
            original_weights.append(dict(zip(joints[i], weights[i])))
        exported.append(lookup[position])
    faces = [('cloth', [(exported[indices[t + k][0]], 0) for k in range(3)])
             for t in range(0, len(indices), 3)]
    fitted = skirt_weights(canonical, faces, original_weights, hip_height,
                           bones['spine05'], bones['upperleg01.L'], bones['upperleg01.R'])
    changed = 0
    for i, original in enumerate(exported):
        if fitted[original] == original_weights[original]:
            continue
        entries = sorted(((joint, weight) for joint, weight in fitted[original].items() if weight > 0),
                         key=lambda pair: (-pair[1], pair[0]))
        entries += [(0, 0.0)] * (4 - len(entries))
        for values, layout in (([p[0] for p in entries], joint_layout),
                               ([p[1] for p in entries], weight_layout)):
            start, stride, fmt = layout
            offset = start + i * stride
            struct.pack_into(fmt, output, offset, *values)
            modified.update(range(offset, offset + struct.calcsize(fmt)))
        changed += 1
    if not changed or any(a != b and i not in modified for i, (a, b) in enumerate(zip(content, output))):
        raise ValueError('Expected only reviewed skirt weight changes')
    return bytes(output), {'changed_exported_vertices': changed, 'hip_height_m': hip_height,
                           'unchanged': 'positions, topology, UVs, normals, textures, materials, bones and other meshes'}


if __name__ == '__main__':
    previous = json.loads(RECORD.read_text()) if RECORD.exists() else {}
    if hashlib.sha256(TARGET.read_bytes()).hexdigest() not in (ORIGINAL_SHA, previous.get('derived_sha256')):
        raise ValueError('Preserve independent runtime character edits before rebuilding')
    result, metrics = prepare(SOURCE.read_bytes())
    TARGET.write_bytes(result)
    record = {'source': str(SOURCE.relative_to(ROOT)), 'source_sha256': ORIGINAL_SHA,
              'source_project_commit': '7344b0a', 'license': 'CC0-1.0',
              'license_record': 'assets/MAKEHUMAN-CC0.txt',
              'recipe': 'tools/prepare_resident_skirt.py + tools/character_fitting.py:skirt_weights',
              'recipe_sha256': {name: hashlib.sha256((ROOT / name).read_bytes()).hexdigest()
                                for name in ('tools/prepare_resident_skirt.py', 'tools/character_fitting.py')},
              'derived_sha256': hashlib.sha256(result).hexdigest(), **metrics}
    RECORD.write_text(json.dumps(record, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps(record, ensure_ascii=False))
