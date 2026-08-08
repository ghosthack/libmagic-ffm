#!/bin/sh
# Build libmagic for windows-x64 from an MSYS2 MINGW64 shell and stage its DLL,
# runtime dependencies, and magic.mgc.
# Usage: build-natives/windows-x64.sh [path-to-file-source]
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="${1:-$ROOT/build/file-5.48}"
PREFIX="$ROOT/build/prefix-windows-x64"
DEST="$ROOT/natives/src/main/resources/natives/windows-x64"
VERSION=5.48

cd "$SRC"
# file 5.48 assumes timespec.tv_sec and time_t are the same type. MinGW64 makes
# the former long and the latter long long; convert the value before passing it.
if ! grep -q 'time_t seconds = (time_t)ts.tv_sec' src/readcdf.c; then
  patch -p1 < "$ROOT/build-natives/patches/file-5.48-mingw-time_t.patch"
fi
./configure --prefix="$PREFIX" --enable-shared --disable-static \
  --disable-zstdlib --disable-libseccomp
make -j"$(nproc)"
make install

rm -rf "$DEST"
mkdir -p "$DEST"
: > "$DEST/manifest.txt"

# Dependencies must be loaded before libmagic.
for runtime in libwinpthread-1.dll libgcc_s_seh-1.dll libiconv-2.dll \
    libintl-8.dll libtre-5.dll libsystre-0.dll zlib1.dll liblzma-5.dll libbz2-1.dll; do
  if [ -f "/mingw64/bin/$runtime" ]; then
    cp "/mingw64/bin/$runtime" "$DEST/$runtime"
    echo "$runtime" >> "$DEST/manifest.txt"
  fi
done

DLL="$(find "$PREFIX/bin" -maxdepth 1 -iname '*magic*.dll' | head -1)"
[ -n "$DLL" ] || { echo "ERROR: libmagic DLL was not installed"; exit 1; }
NAME="$(basename "$DLL")"
cp "$DLL" "$DEST/$NAME"
echo "$NAME" >> "$DEST/manifest.txt"

cp "$PREFIX/share/misc/magic.mgc" "$DEST/magic.mgc"
echo "magic.mgc" > "$DEST/resources.txt"

ALLOWED='magic|libwinpthread|libgcc_s_seh|libiconv|libintl|libtre|libsystre|zlib1|liblzma|libbz2|KERNEL32|USER32|ADVAPI32|SHELL32|ole32|OLEAUT32|SHLWAPI|bcrypt|msvcrt|ntdll|api-ms-'
for file in "$DEST"/*.dll; do
  if objdump -p "$file" | awk '/DLL Name:/{print $3}' | grep -viE "^($ALLOWED)"; then
    echo "ERROR: $file imports unexpected DLLs (above)"; exit 1
  fi
done

cp "$SRC/COPYING" "$DEST/COPYING.libmagic"
cp /mingw64/share/licenses/libsystre/LICENSE "$DEST/LICENSE.libsystre"
cp /mingw64/share/licenses/libtre/LICENSE "$DEST/LICENSE.libtre"
cp /mingw64/share/licenses/gettext-runtime/intl/COPYING.LIB "$DEST/COPYING.LIB.gettext"
cp /mingw64/share/licenses/libiconv/COPYING.LIB "$DEST/COPYING.LIB.libiconv"
{
  echo "file/libmagic $VERSION (windows-x64), built from source with MSYS2 mingw-w64"
  echo "Source: https://www.astron.com/pub/file/file-$VERSION.tar.gz"
  echo "License: BSD-2-Clause (see COPYING.libmagic)"
  echo "Local patch: file-5.48-mingw-time_t.patch (safe timespec.tv_sec to time_t conversion)"
  echo "Runtime support: libsystre 1.0.2 (BSD-2), libtre 0.9.0 (BSD),"
  echo "  gettext-runtime/libintl and libiconv (LGPL-2.1+); see bundled license files"
  echo "configure: --enable-shared --disable-static --disable-zstdlib --disable-libseccomp"
} > "$DEST/BUILD-INFO.txt"

echo "Staged $(ls "$DEST" | wc -l) files into $DEST"
