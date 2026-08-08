#!/bin/sh
# Build libmagic for macos-arm64 and stage the dylib plus magic.mgc.
# Usage: build-natives/macos-arm64.sh [path-to-file-source]
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="${1:-$ROOT/build/file-5.48}"
PREFIX="$ROOT/build/prefix-macos-arm64"
DEST="$ROOT/natives/src/main/resources/natives/macos-arm64"
VERSION=5.48

cd "$SRC"
./configure --prefix="$PREFIX" --enable-shared --disable-static
make -j"$(sysctl -n hw.ncpu)"
make install

rm -rf "$DEST"
mkdir -p "$DEST"

DYLIB="$PREFIX/lib/$(readlink "$PREFIX/lib/libmagic.dylib")"
NAME="$(basename "$(otool -D "$DYLIB" | tail -1)")"
cp "$DYLIB" "$DEST/$NAME"
chmod 644 "$DEST/$NAME"
install_name_tool -id "@loader_path/$NAME" "$DEST/$NAME"
echo "$NAME" > "$DEST/manifest.txt"

cp "$PREFIX/share/misc/magic.mgc" "$DEST/magic.mgc"
echo "magic.mgc" > "$DEST/resources.txt"

if otool -L "$DEST/$NAME" | tail -n +2 \
    | grep -vE '@loader_path/|/usr/lib/|/System/Library/'; then
  echo "ERROR: $NAME has non-system dependencies (above)"; exit 1
fi

cp "$SRC/COPYING" "$DEST/COPYING.libmagic"
{
  echo "file/libmagic $VERSION (macos-arm64), built from unmodified source"
  echo "Source: https://www.astron.com/pub/file/file-$VERSION.tar.gz"
  echo "License: BSD-2-Clause (see COPYING.libmagic)"
  echo "configure: --enable-shared --disable-static"
} > "$DEST/BUILD-INFO.txt"

echo "Staged $(ls "$DEST" | wc -l | tr -d ' ') files into $DEST"
