"""Fetch the approved Poly Haven sample set and retain verifiable CC0 provenance.

Uses the public API only during production; the game never contacts the service.
Existing files must match the upstream checksum and are never silently replaced.
"""
import argparse
import datetime
import hashlib
import json
from pathlib import Path, PurePosixPath
import re
import urllib.parse
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
SELECTION = {
    'modern_arm_chair_01': 'models',
    'desk_lamp_arm_01': 'models',
    'painted_plaster_wall': 'textures',
    'concrete_floor_01': 'textures',
    'clean_asphalt': 'textures',
}
USER_AGENT = 'TodayOff-AssetReview/1.0 (local game production; Poly Haven CC0 sample)'


def safe_path(base, relative):
    parts = PurePosixPath(relative)
    if parts.is_absolute() or '..' in parts.parts or '\\' in relative or not parts.parts:
        raise ValueError(f'Unsafe asset path: {relative}')
    result = base / relative
    if not result.resolve().is_relative_to(base.resolve()):
        raise ValueError(f'Asset path escapes destination: {relative}')
    return result


def validate_origin(url, host):
    parsed = urllib.parse.urlparse(url)
    if parsed.scheme != 'https' or parsed.hostname != host or parsed.username or parsed.password:
        raise ValueError(f'Unexpected asset origin: {url}')


class AssetRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        validate_origin(newurl, urllib.parse.urlparse(req.full_url).hostname)
        return super().redirect_request(req, fp, code, msg, headers, newurl)


def request(url, host):
    validate_origin(url, host)
    opener = urllib.request.build_opener(AssetRedirect())
    response = opener.open(urllib.request.Request(url, headers={'User-Agent': USER_AGENT}), timeout=60)
    final = urllib.parse.urlparse(response.url)
    if final.scheme != 'https' or final.hostname != host:
        response.close()
        raise ValueError('Asset redirected to an unexpected origin')
    return response


def metadata(endpoint):
    with request('https://api.polyhaven.com/' + endpoint, 'api.polyhaven.com') as response:
        return json.load(response)


def checked_download(destination, entry):
    size, md5 = entry['size'], entry['md5']
    if not isinstance(size, int) or not 0 < size <= 64 * 1024 * 1024 or not re.fullmatch('[a-fA-F0-9]{32}', md5):
        raise ValueError('Invalid asset size or digest')
    def valid(path):
        return path.stat().st_size == size and hashlib.md5(path.read_bytes()).hexdigest() == md5
    if destination.exists():
        if not valid(destination):
            raise ValueError(f'Existing asset differs; preserve and review: {destination}')
    else:
        destination.parent.mkdir(parents=True, exist_ok=True)
        temporary = destination.with_name(destination.name + '.tmp')
        # Exclusive creation preserves any interrupted attempt for inspection.
        with temporary.open('xb') as stream, request(entry['url'], 'dl.polyhaven.org') as response:
            received = 0
            while chunk := response.read(1024 * 1024):
                received += len(chunk)
                if received > size:
                    raise ValueError('Asset exceeded declared size')
                stream.write(chunk)
        if not valid(temporary):
            raise ValueError(f'Asset checksum mismatch: {temporary}')
        temporary.replace(destination)
    return {'bytes': size, 'upstream_md5': md5,
            'sha256': hashlib.sha256(destination.read_bytes()).hexdigest(), 'url': entry['url']}


def fetch(output):
    output = output.resolve()
    catalog = {kind: metadata('assets?type=' + kind) for kind in set(SELECTION.values())}
    assets = []
    for asset_id, kind in SELECTION.items():
        data = metadata('files/' + asset_id)
        asset_dir = output / asset_id
        if kind == 'models':
            model = data['gltf']['2k']['gltf']
            files = {asset_id + '_2k.gltf': model, **model['include']}
        else:
            files = {asset_id + '_' + channel + '_2k.jpg': data[channel]['2k']['jpg']
                     for channel in ('Diffuse', 'nor_gl', 'arm')}
        records = {}
        for relative, entry in files.items():
            records[relative] = checked_download(safe_path(asset_dir, relative), entry)
            print('VERIFIED', asset_id, relative, flush=True)
        source = catalog[kind][asset_id]
        assets.append({'id': asset_id, 'category': kind, 'source': 'https://polyhaven.com/a/' + asset_id,
                       'authors': source['authors'], 'license': 'CC0-1.0',
                       'license_url': 'https://polyhaven.com/license',
                       'license_text_url': 'https://creativecommons.org/publicdomain/zero/1.0/legalcode.en',
                       'resolution': '2k', 'source_dimensions_mm': source.get('dimensions'), 'files': records})
    output.mkdir(parents=True, exist_ok=True)
    path = output / 'provenance.json'
    first_retrieved = json.loads(path.read_text())['retrieved_date'] if path.exists() else datetime.date.today().isoformat()
    record = {'schema_version': 1, 'provider': 'Poly Haven', 'credit': 'Powered by Poly Haven',
              'retrieved_date': first_retrieved, 'assets': assets}
    data = json.dumps(record, ensure_ascii=False, indent=2) + '\n'
    if path.exists() and path.read_text() != data:
        raise ValueError('Provenance differs; review existing record before updating')
    path.write_text(data)
    print('ASSET_SET_VERIFIED', len(assets))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, default=ROOT / 'assets/polyhaven')
    fetch(parser.parse_args().output)
