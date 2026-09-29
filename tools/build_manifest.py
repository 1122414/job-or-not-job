"""Identify runtime inputs, including uncommitted changes, for reproducible evidence."""
from pathlib import Path
import argparse
import datetime
import hashlib
import json
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]


def configured_renderer(config, platform):
    """Record the target platform override; actual runtime fallback is separate."""
    for suffix in ('.' + platform, ''):
        match = re.search(r'^renderer/rendering_method' + re.escape(suffix) + r'="([^"]+)"$', config, re.M)
        if match:
            return match.group(1)
    raise ValueError('Missing configured rendering method')


def sha256(path):
    with path.open('rb') as stream:
        digest = hashlib.sha256()
        for chunk in iter(lambda: stream.read(1024 * 1024), b''):
            digest.update(chunk)
        return digest.hexdigest()


def runtime_inputs(root=ROOT):
    files = [root / 'project.godot', root / 'export_presets.cfg']
    for folder in ('assets', 'scenes', 'scripts'):
        files.extend(p for p in (root / folder).rglob('*') if p.is_file()
                     and p.name != '.DS_Store' and not p.name.endswith('.tmp'))
    return {p.relative_to(root).as_posix(): sha256(p) for p in sorted(files)}


def source_identity(root=ROOT):
    inputs = runtime_inputs(root)
    digest = hashlib.sha256(json.dumps(inputs, sort_keys=True).encode()).hexdigest()
    commit = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=root, text=True).strip()
    status = subprocess.check_output(
        ['git', 'status', '--porcelain', '--untracked-files=all', '--',
         'project.godot', 'export_presets.cfg', 'assets', 'scenes', 'scripts'], cwd=root)
    version = re.search(r'^const VERSION := (\d+)', (root / 'scripts/save_game.gd').read_text(), re.M)
    if not version:
        raise ValueError('Cannot identify save schema')
    return {'source_commit': commit, 'runtime_dirty': bool(status),
            'source_sha256': digest, 'runtime_inputs': inputs,
            'save_schema': int(version.group(1))}


def manifest(root=ROOT):
    return {'manifest_version': 1,
            'created_utc': datetime.datetime.now(datetime.timezone.utc).isoformat(),
            **source_identity(root)}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(manifest(), ensure_ascii=False, indent=2) + '\n')
