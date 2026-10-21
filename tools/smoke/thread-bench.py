#!/usr/bin/env python3
"""Measure 1/2/4/8 model threads and compare local capture bytes (never upload outputs)."""
import argparse
import filecmp
import json
import os
import re
from pathlib import Path
import shlex
import shutil
import subprocess
import time


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('core', choices=('nes', 'snes', 'gba', 'md', 'sms'))
    p.add_argument('source', type=Path, help='core checkout, unchanged across measurements')
    p.add_argument('rom', type=Path)
    p.add_argument('output', type=Path, help='local, ignored output directory')
    p.add_argument('--frames', type=int, default=120)
    a = p.parse_args()
    if a.frames < 60:
        p.error('use at least 60 frames so the harness captures an image')
    source, rom, output = a.source.resolve(), a.rom.resolve(), a.output.resolve()
    if not rom.is_file():
        p.error('ROM not found')
    smoke = Path(__file__).resolve().parent
    output.mkdir(parents=True, exist_ok=False)
    runner = shlex.split(os.environ.get('DOCKER_RUN', 'simrun' if shutil.which('simrun') else 'docker run --rm'))
    cache = [] if any('simrun' in x for x in runner) else ['-e', 'CCACHE_DISABLE=1']
    image = 'verilator/verilator:v5.028' if a.core == 'gba' else 'verilator/verilator:latest'
    image = subprocess.check_output(['docker', 'image', 'inspect', '--format', '{{.Id}}', image], text=True).strip()
    (output / 'image.txt').write_text(image + '\n')
    env = os.environ.copy()
    env['SMOKE_BUILD'] = str(output / 'models')
    env['SMOKE_' + a.core.upper() + '_SRC'] = str(source)
    results = []
    baseline = None
    for n in (1, 2, 4, 8):
        tag = 'threads' + str(n)
        captures = output / tag
        captures.mkdir()
        prefix = env.get('SIM_PREFIX', 'sim' + str(os.getpid()))
        cmd = runner + cache + ['--name', prefix + '_threadbench_' + a.core + '_' + str(n), '--user', f'{os.getuid()}:{os.getgid()}',
                        '-v', str(smoke) + ':/s:ro', '-v', str(source) + ':/r:ro', '-v', str(output) + ':/b',
                        '-e', 'SMOKE_BUILD=/b/models', '-e', 'VERILATOR_THREADS=' + str(n),
                        '-w', '/s/' + a.core, '--entrypoint', 'sh', image, 'build.sh', tag, '/r']
        start = time.monotonic()
        with (output / (tag + '-build.log')).open('w') as log:
            subprocess.run(cmd, stdout=log, stderr=subprocess.STDOUT, check=True)
        generated = output / 'models' / a.core / tag / 'obj/obj'
        compiled = [int(m.group(1)) for f in generated.glob('*.cpp')
                    for m in re.finditer(r'::threads\(\) const \{ return (\d+);', f.read_text())]
        if compiled != [n]:
            raise RuntimeError(f'generated model thread count {compiled}, expected {n}')
        build_seconds = time.monotonic() - start
        start = time.monotonic()
        with (output / (tag + '-run.log')).open('w') as log:
            subprocess.run(['sh', str(smoke / a.core / 'run_game.sh'), tag, 'game', str(rom), str(a.frames), str(captures)],
                           env=env, stdout=log, stderr=subprocess.STDOUT, check=True)
        seconds = time.monotonic() - start
        runtime = re.search(r'model threads: (\d+)', (captures / 'game.stderr').read_text())
        if not runtime or int(runtime.group(1)) != n:
            raise RuntimeError('runtime thread pool does not match compiled model')
        # Compare actual bytes, plus the complete deterministic per-frame log.
        files = sorted(x.name for x in captures.glob('game*') if x.suffix in ('.ppm', '.aud', '.bin', '.log'))
        if not any(x.endswith('.ppm') for x in files) or not any(x.endswith('.aud') for x in files):
            raise RuntimeError('missing frame/audio captures')
        if a.core != 'sms' and not any(x.endswith('.bin') for x in files):
            raise RuntimeError('missing RAM capture')
        if n == 1:
            baseline = files
            identical = True
        else:
            identical = files == baseline and all(filecmp.cmp(output / 'threads1' / f, captures / f, shallow=False) for f in files)
        row = dict(threads=n, build_seconds=round(build_seconds, 2), run_seconds=round(seconds, 2), identical=identical,
                   captured_files=len(files), frames=sum(f.endswith('.ppm') for f in files),
                   ram=sum(f.endswith('.bin') for f in files), audio=sum(f.endswith('.aud') for f in files), speedup=round(results[0]['run_seconds'] / seconds, 3) if results else 1.0)
        results.append(row)
        (output / 'measurements.json').write_text(json.dumps(results, indent=2) + '\n')
        print(json.dumps(row), flush=True)
    if any(not row['identical'] for row in results):
        raise RuntimeError('threading changed captured bytes; leave it disabled')


if __name__ == '__main__':
    main()
