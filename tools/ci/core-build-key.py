#!/usr/bin/env python3
"""Key deterministic Gowin outputs by build inputs, excluding non-build files."""
import hashlib
import os
from pathlib import Path
import subprocess
import sys

source = Path(sys.argv[1])
recipe = Path(__file__).resolve().parents[2]
tree = subprocess.check_output(['git', '-C', str(source), 'ls-tree', '-rz', '--full-tree', 'HEAD'])
digest = hashlib.sha256()
for entry in tree.split(b'\0'):
    if not entry:
        continue
    path = entry.split(b'\t', 1)[1]
    if path.startswith((b'sim/', b'tools/', b'docs/')) or path.endswith(b'.md'):
        continue
    # Includes file modes and submodule gitlinks, just like the local cache.
    digest.update(entry + b'\0')
for name in ('CORE', 'BOARD', 'TANGCORE_VARIANT', 'GOWIN_VERSION', 'GOWIN_SHA256', 'BUILD_RECIPE_VERSION', 'RUNNER_OS', 'RUNNER_ARCH'):
    digest.update(f'{name}={os.environ[name]}\n'.encode())
# Conservatively invalidate when the workflow or key recipe changes.
for path in (recipe / '.github/workflows/cores.yml', Path(__file__)):
    digest.update(path.read_bytes())
key = f'core-build-{os.environ["CORE"]}-{os.environ["BOARD"]}-{os.environ["TANGCORE_VARIANT"]}-{digest.hexdigest()}'
commit = subprocess.check_output(['git', '-C', str(source), 'rev-parse', 'HEAD'], text=True).strip()
print(f'Build source: cassiostp/{os.environ["CORE"]}@{commit}')
print(f'Build output cache key: {key}')
with open(os.environ['GITHUB_OUTPUT'], 'a') as output:
    output.write(f'key={key}\n')
with open(os.environ['GITHUB_STEP_SUMMARY'], 'a') as summary:
    summary.write(f'Build source: `cassiostp/{os.environ["CORE"]}@{commit}`\n\nOutput cache key: `{key}`\n\n')
