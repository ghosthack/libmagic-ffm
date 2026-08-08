#!/bin/sh
# Build libmagic for linux-x64 and stage the shared library plus magic.mgc.
# Prerequisites: gcc, make, zlib/bzip2/xz development headers, patchelf.
# Usage: build-natives/linux-x64.sh [path-to-file-source]
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="${1:-$ROOT/build/file-5.48}"
PREFIX="$ROOT/build/prefix-linux-x64"
DEST="$ROOT/natives/src/main/resources/natives/linux-x64"
VERSION=5.48

cd "$SRC"
./configure --prefix="$PREFIX" --enable-shared --disable-static \
  --disable-zstdlib --disable-libseccomp
make -j"$(nproc)"
make install

rm -rf "$DEST"
mkdir -p "$DEST"

SO="$(readlink -f "$PREFIX/lib/libmagic.so")"
NAME="$(patchelf --print-soname "$SO")"
cp "$SO" "$DEST/$NAME"
chmod 644 "$DEST/$NAME"
echo "$NAME" > "$DEST/manifest.txt"

cp "$PREFIX/share/misc/magic.mgc" "$DEST/magic.mgc"
echo "magic.mgc" > "$DEST/resources.txt"

if readelf -d "$DEST/$NAME" | awk '/NEEDED/ {print $NF}' | tr -d '[]' \
    | grep -vE '^(libc|libm|libpthread|libdl|librt|libz|libbz2|liblzma)\.so|^ld-linux'; then
  echo "ERROR: $NAME has unexpected dependencies (above)"; exit 1
fi

cp "$SRC/COPYING" "$DEST/COPYING.libmagic"
{
  echo "file/libmagic $VERSION (linux-x64), built from unmodified source"
  echo "Source: https://www.astron.com/pub/file/file-$VERSION.tar.gz"
  echo "License: BSD-2-Clause (see COPYING.libmagic)"
  echo "configure: --enable-shared --disable-static --disable-zstdlib --disable-libseccomp"
} > "$DEST/BUILD-INFO.txt"

echo "Staged $(ls "$DEST" | wc -l | tr -d ' ') files into $DEST"
