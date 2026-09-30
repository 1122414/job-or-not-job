"""Repair non-convex legacy GLB skin weights without changing geometry or rigs.

The returned row record retains the exact original float bytes. It allows the
repair to be reversed for source comparison without storing another whole GLB.
"""
import hashlib
import json
import math
from pathlib import Path
import struct


def repair(content):
    length, kind = struct.unpack_from('<II', content, 12)
    if kind != 0x4e4f534a:
        raise ValueError('Expected GLB JSON chunk')
    doc = json.loads(content[20:20 + length])
    output = bytearray(content)
    rows = []
    seen = set()
    negative = 0
    for mesh in doc['meshes']:
        for primitive in mesh['primitives']:
            accessor = primitive.get('attributes', {}).get('WEIGHTS_0')
            if accessor is None or accessor in seen:
                continue
            seen.add(accessor)
            item = doc['accessors'][accessor]
            if item['componentType'] != 5126 or item['type'] != 'VEC4' or 'sparse' in item:
                raise ValueError('Expected legacy float VEC4 skin weights')
            view = doc['bufferViews'][item['bufferView']]
            start = 28 + length + view.get('byteOffset', 0) + item.get('byteOffset', 0)
            for vertex in range(item['count']):
                offset = start + vertex * view.get('byteStride', 16)
                values = struct.unpack_from('<4f', content, offset)
                if not all(math.isfinite(value) for value in values):
                    raise ValueError('Non-finite skin weights')
                if min(values) >= 0:
                    if not math.isclose(sum(values), 1, abs_tol=1e-5):
                        raise ValueError('Unnormalized skin weights')
                    continue
                positive = [max(0, value) for value in values]
                total = sum(positive)
                if total <= 0:
                    raise ValueError('No positive skin influence')
                negative += sum(value < 0 for value in values)
                rows.append({'mesh': mesh['name'], 'vertex': vertex, 'offset': offset,
                             'original_hex': content[offset:offset + 16].hex()})
                struct.pack_into('<4f', output, offset, *(value / total for value in positive))
    return bytes(output), {'negative_values_removed': negative, 'rows': rows}


if __name__ == '__main__':
    root = Path(__file__).resolve().parents[1]
    record_path = root / 'assets/characters/skin_repair_provenance.json'
    previous = json.loads(record_path.read_text()) if record_path.exists() else {}
    records = {}
    original_hashes = {
        'casual': '534333416a2948c3ad3227fe0c7bd55aaec03c2f4bd0ee599ca261fd7d2ce577',
        'office': 'b5de9614956871431899d337711902f198fb7056a7e6f3cf6c0b942f447a19a1',
        'office_female': '4d6cfa47c63f10e6ed07a644efa0efcfe381f5934d926251992c59900e81243d'}
    for name in ['casual', 'office', 'office_female']:
        path = root / 'assets/characters' / (name + '.glb')
        raw = path.read_bytes()
        before = hashlib.sha256(raw).hexdigest()
        if before == previous.get('characters', {}).get(name, {}).get('derived_sha256'):
            records[name] = previous['characters'][name]
            continue
        if before != original_hashes[name]:
            raise ValueError('Preserve independently modified character: ' + name)
        fixed, metrics = repair(raw)
        if not metrics['rows']:
            raise ValueError('No legacy defect to repair: ' + name)
        path.write_bytes(fixed)
        records[name] = {'source_sha256': before, 'derived_sha256': hashlib.sha256(fixed).hexdigest(), **metrics}
    record_path.write_text(json.dumps({'scope': 'Only invalid WEIGHTS_0 rows; geometry, skeleton, materials, morphs and valid rows unchanged',
                                      'license': 'CC0-1.0', 'source_project_commit': '6afdb4e',
                                      'recipe': 'tools/repair_character_skin.py', 'characters': records}, indent=2) + '\n')
    for name, record in records.items():
        print(name, 'negative values repaired', record['negative_values_removed'], 'rows', len(record['rows']))
