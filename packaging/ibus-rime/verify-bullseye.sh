#!/usr/bin/env bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
printf 'deb http://archive.debian.org/debian bullseye main\ndeb http://archive.debian.org/debian-security bullseye-security main\n' > /etc/apt/sources.list
printf 'Acquire::Check-Valid-Until "false";\n' > /etc/apt/apt.conf.d/99archive
apt-get update -qq
apt-get install -y --no-install-recommends \
    ibus libnotify4 file binutils python3 dbus-x11 xvfb
test "$(dpkg --print-architecture)" = arm64
test "$(getconf GNU_LIBC_VERSION)" = 'glibc 2.31'
mkdir /tmp/appimage-test
cd /tmp/appimage-test
cp /project/dist/ibus-rime-bullseye-aarch64.AppImage ./ibus-rime.AppImage
chmod +x ibus-rime.AppImage
file ibus-rime.AppImage
./ibus-rime.AppImage --appimage-extract >/dev/null
export APPDIR="$PWD/squashfs-root"
export LD_LIBRARY_PATH="$APPDIR/usr/lib"
export RIME_PLUGINS_DIR="$APPDIR/usr/lib/rime-plugins"
python3 - <<'PY'
import os, re, subprocess
from pathlib import Path
root = Path(os.environ['APPDIR'])
for path in sorted(root.rglob('*')):
    if not path.is_file() or path.read_bytes()[:4] != b'\x7fELF':
        continue
    header = subprocess.check_output(['readelf', '-h', str(path)], text=True)
    assert 'AArch64' in header, path
    versions = subprocess.check_output(['readelf', '--version-info', str(path)], text=True)
    for version in re.findall(r'GLIBC_(\d+(?:\.\d+)+)', versions):
        assert tuple(map(int, version.split('.'))) <= (2,31), (path, version)
    deps = subprocess.run(['ldd', str(path)], text=True, capture_output=True)
    assert 'not found' not in deps.stdout + deps.stderr, (path, deps.stdout, deps.stderr)
print('All bundled ELF files: AArch64; GLIBC <= 2.31; dependencies resolved')
PY
APPIMAGE_EXTRACT_AND_RUN=1 ./ibus-rime.AppImage version
APPIMAGE_EXTRACT_AND_RUN=1 ./ibus-rime.AppImage ibus-engine-rime --help
mkdir -p /tmp/rime-user
APPIMAGE_EXTRACT_AND_RUN=1 ./ibus-rime.AppImage rime_deployer --build /tmp/rime-user "$APPDIR/usr/share/rime-data"
printf '\nPASS: bullseye arm64 CLI/deployment and ELF checks\n'
