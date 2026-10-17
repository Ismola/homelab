"""Install a reviewed immutable source revision without registry credentials."""
import io
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tarfile
import urllib.request

revision = os.environ['SOURCE_REVISION']
assert len(revision) == 40 and all(c in '0123456789abcdef' for c in revision)
request = urllib.request.Request(
    f'https://codeload.github.com/Ismola/bible-jwpub/tar.gz/{revision}',
    headers={'User-Agent': 'BibleShelf Kubernetes bootstrap'},
)
with urllib.request.urlopen(request, timeout=90) as response:
    content = response.read(8 * 1024 * 1024)
with tarfile.open(fileobj=io.BytesIO(content), mode='r:gz') as archive:
    archive.extractall('/runtime/download', filter='data')
source = next(Path('/runtime/download').iterdir())
shutil.move(str(source), '/runtime/source')
subprocess.run([
    sys.executable, '-m', 'pip', 'install', '--no-cache-dir',
    '--disable-pip-version-check', '--only-binary=:all:',
    '--target', '/runtime/site', '-r', '/runtime/source/requirements.lock',
], check=True)
print(f'Prepared BibleShelf revision {revision}', flush=True)
