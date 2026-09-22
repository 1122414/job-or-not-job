"""Synchronize authorized project records; never overwrite divergent vault edits."""
from pathlib import Path
import hashlib
import json
import shutil

ROOT = Path(__file__).resolve().parents[1]
VAULT = Path('/Users/geminchen/Documents/MyKnowledgeBase/Obsidian/项目/游戏/上班全流程模拟器（开放世界版本）')
MIRROR = VAULT / '项目文档'
CHECKSUMS = MIRROR / '.同步校验.json'


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    previous = json.loads(CHECKSUMS.read_text()) if CHECKSUMS.exists() else {}
    files = sorted([*ROOT.glob('*.md'), *ROOT.glob('*.docx'), *ROOT.glob('docs/**/*.md'), *ROOT.glob('docs/evidence/**/*.png')])
    conflicts = []
    for source in files:
        rel = source.relative_to(ROOT).as_posix()
        destination = MIRROR / rel
        sha = digest(source)
        if destination.exists() and digest(destination) not in (sha, previous.get(rel)):
            # Leave the original intact. A versioned sibling preserves our proposed copy.
            proposed = destination.with_name(destination.stem + '.项目版本-' + sha[:8] + destination.suffix)
            proposed.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source, proposed)
            conflicts.append(rel)
            continue
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, destination)
        previous[rel] = sha
    CHECKSUMS.write_text(json.dumps(previous, ensure_ascii=False, indent=2) + '\n')
    index = VAULT / '项目记录索引.md'
    existing = index.read_text() if index.exists() else '# 项目记录索引\n'
    begin, end = '<!-- project-sync:start -->', '<!-- project-sync:end -->'
    block = begin + '\n## 当前项目文档\n\n' + '\n'.join(
        f'- [{p.stem}](<项目文档/{p.relative_to(ROOT).as_posix()}>)' for p in files
    ) + '\n' + end
    if begin in existing and end in existing:
        a, b = existing.index(begin), existing.index(end) + len(end)
        existing = existing[:a] + block + existing[b:]
    else:
        existing += '\n\n' + block + '\n'
    index.write_text(existing)
    print(f'同步 {len(files) - len(conflicts)} 项；冲突 {len(conflicts)} 项。')
    for rel in conflicts:
        print('保留独立编辑：', rel)


if __name__ == '__main__':
    main()
