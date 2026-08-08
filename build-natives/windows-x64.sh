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
./configure --prefix="$PREFIX" --enable-shared --disable-static --disable-libseccomp
make -j"$(nproc)"
make install

rm -rf "$DEST"
mkdir -p "$DEST"
: > "$DEST/manifest.txt"

# Dependencies must be loaded before libmagic.
for runtime in libwinpthread-1.dll libgcc_s_seh-1.dll zlib1.dll liblzma-5.dll libbz2-1.dll; do
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

ALLOWED='magic|libwinpthread|libgcc_s_seh|zlib1|liblzma|libbz2|KERNEL32|USER32|ADVAPI32|SHELL32|ole32|OLEAUT32|SHLWAPI|bcrypt|msvcrt|ntdll|api-ms-'
for file in "$DEST"/*.dll; do
  if objdump -p "$file" | awk '/DLL Name:/{print $3}' | grep -viE "^($ALLOWED)"; then
    echo "ERROR: $file imports unexpected DLLs (above)"; exit 1
  fi
done

cp "$SRC/COPYING" "$DEST/COPYING.libmagic"
{
  echo "file/libmagic $VERSION (windows-x64), built from unmodified source with MSYS2 mingw-w64"
  echo "Source: https://www.astron.com/pub/file/file-$VERSION.tar.gz"
  echo "License: BSD-2-Clause (see COPYING.libmagic)"
  echo "configure: --enable-shared --disable-static --disable-libseccomp"
} > "$DEST/BUILD-INFO.txt"

echo "Staged $(ls "$DEST" | wc -l) files into $DEST"
