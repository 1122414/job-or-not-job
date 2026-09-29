"""Rebuild city sound assets from pinned CC0 originals using installed ffmpeg."""
import array
import hashlib
import io
import json
from pathlib import Path
import subprocess
import sys
import wave
import zipfile

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'production/audio/cc0-2026-09-30'
OUTPUT = ROOT / 'assets/audio/city'
RATE = 44100
SOURCES = {
    'traffic.ogg': ('high-traffic-road-sounds', 'IgnasD'),
    'birds.ogg': ('ambient-bird-sounds', 'isaiah658'),
    'engine.wav': ('racing-car-engine-sound-loops', 'domasx2; original pdsounds public-domain recording'),
    'waves.flac': ('beach-ocean-waves', 'jasinski; excerpt by qubodup'),
    'steps.zip': ('different-steps-on-wood-stone-leaves-gravel-and-mud', 'TinyWorlds'),
    'shop.zip': ('the-shop', 'LEGIT Audio; only the free OpenGameArt files are CC0'),
}


def sha(data):
    return hashlib.sha256(data).hexdigest()


def make(name, original, member='', loop=False, lowpass=0):
    data = (SOURCE / original).read_bytes()
    if member:
        with zipfile.ZipFile(io.BytesIO(data)) as archive:
            data = archive.read(member)
    command = ['ffmpeg', '-v', 'error', '-i', 'pipe:0', '-vn', '-ac', '1', '-ar', str(RATE)]
    if lowpass:
        command += ['-af', f'lowpass=f={lowpass}']
    raw = subprocess.check_output(command + ['-f', 'f32le', 'pipe:1'], input=data)
    values = array.array('f', raw)
    if sys.byteorder != 'little':
        values.byteswap()
    dc = sum(values) / len(values)
    values = array.array('f', (v - dc for v in values))
    fade = min(RATE, len(values) // 5) if loop else min(150, len(values) // 10)
    if loop:
        # End crossfades into the original head; the next frame is head[fade].
        blended = [values[-fade+i] * (1-i/(fade-1)) + values[i] * i/(fade-1) for i in range(fade)]
        values = values[fade:-fade] + array.array('f', blended)
    else:
        for i in range(fade):
            values[i] *= i / fade
            values[-i-1] *= i / fade
    gain = 0.5 / max(abs(v) for v in values)
    pcm = array.array('h', (round(v * gain * 32767) for v in values))
    if sys.byteorder != 'little':
        pcm.byteswap()
    buffer = io.BytesIO()
    with wave.open(buffer, 'wb') as wav:
        wav.setnchannels(1); wav.setsampwidth(2); wav.setframerate(RATE)
        wav.writeframes(pcm.tobytes())
    path = OUTPUT / (name + '.wav')
    path.write_bytes(buffer.getvalue())
    return dict(file=path.relative_to(ROOT).as_posix(), source=original, member=member,
                seconds=len(values)/RATE, mono=True, rate=RATE, loop=loop,
                lowpass_hz=lowpass, crossfade_frames=fade if loop else 0,
                pcm_sha256=sha(pcm.tobytes()), sha256=sha(path.read_bytes()),
                normalized_peak_db=-6.021, loop_boundary_delta=abs(values[-1]-values[0])*gain)


def main():
    OUTPUT.mkdir(parents=True, exist_ok=True)
    originals = json.loads((SOURCE / 'downloads.json').read_text())
    for row in originals:
        if sha((SOURCE / row['file']).read_bytes()) != row['sha256']:
            raise ValueError('Original changed: ' + row['file'])
        slug, author = SOURCES[row['file']]
        row.update(page='https://opengameart.org/content/' + slug, author=author,
                   license='CC0-1.0', license_url='https://creativecommons.org/publicdomain/zero/1.0/')
    files = [make('traffic', 'traffic.ogg', loop=True, lowpass=1200),
             make('birds', 'birds.ogg', loop=True),
             make('engine', 'engine.wav', loop=True),
             make('waves', 'waves.flac', loop=True),
             make('room', 'shop.zip', 'TheShopCollection_convenience_store_drinks_fridge_drone.wav', loop=True, lowpass=1800)]
    for name, member, lowpass in [('stone', 'stone01.ogg', 0), ('carpet', 'stone01.ogg', 750),
                                 ('wood1', 'wood01.ogg', 0), ('wood2', 'wood02.ogg', 0),
                                 ('wood3', 'wood03.ogg', 0), ('grass1', 'leaves01.ogg', 0),
                                 ('grass2', 'leaves02.ogg', 0)]:
        files.append(make(name, 'steps.zip', member, lowpass=lowpass))
    info = dict(date='2026-09-30', originals=originals, derived=files,
                processing='Mono 44100 Hz; DC removed; loop tail/head crossfade; peak normalized to -6.02 dBFS; selected lowpass. No newly recorded voice.',
                tool=subprocess.check_output(['ffmpeg', '-version'], text=True).splitlines()[0],
                quality_status='Technical import; final listening and audiovisual acceptance remain open.')
    (OUTPUT / 'provenance.json').write_text(json.dumps(info, ensure_ascii=False, indent=2)+'\n')
    print(json.dumps({r['file']: round(r['seconds'], 3) for r in files}, indent=2))


if __name__ == '__main__':
    main()
