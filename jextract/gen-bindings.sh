#!/bin/sh
# Generate the complete public libmagic API and point it at LibMagicLibs.
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
JX="${JEXTRACT_HOME:-$ROOT/tools/jextract-22}/bin/jextract"
PREFIX="$ROOT/build/prefix-macos-arm64"
OUT="$ROOT/core/src/main/java"
PKG="io.github.ghosthack.libmagicffm.libmagic"
SDK="$(xcrun --show-sdk-path)"

[ -x "$JX" ] || { echo "jextract not found at $JX"; exit 1; }
[ -f "$PREFIX/include/magic.h" ] || { echo "run build-natives/macos-arm64.sh first"; exit 1; }

GEN_DIR="$OUT/$(echo "$PKG" | tr . /)"
rm -rf "$GEN_DIR"

"$JX" --output "$OUT" -t "$PKG" \
  --header-class-name LibMagic \
  -I "$SDK/usr/include" \
  -I "$PREFIX/include" \
  -l ":$PREFIX/lib/libmagic.dylib" \
  --include-function magic_open \
  --include-function magic_close \
  --include-function magic_getpath \
  --include-function magic_file \
  --include-function magic_descriptor \
  --include-function magic_buffer \
  --include-function magic_error \
  --include-function magic_getflags \
  --include-function magic_setflags \
  --include-function magic_version \
  --include-function magic_load \
  --include-function magic_load_buffers \
  --include-function magic_compile \
  --include-function magic_check \
  --include-function magic_list \
  --include-function magic_errno \
  --include-function magic_setparam \
  --include-function magic_getparam \
  --include-function magic_getmaxparam \
  --include-typedef magic_t \
  --include-constant MAGIC_NONE \
  --include-constant MAGIC_DEBUG \
  --include-constant MAGIC_SYMLINK \
  --include-constant MAGIC_COMPRESS \
  --include-constant MAGIC_DEVICES \
  --include-constant MAGIC_MIME_TYPE \
  --include-constant MAGIC_CONTINUE \
  --include-constant MAGIC_CHECK \
  --include-constant MAGIC_PRESERVE_ATIME \
  --include-constant MAGIC_RAW \
  --include-constant MAGIC_ERROR \
  --include-constant MAGIC_MIME_ENCODING \
  --include-constant MAGIC_MIME \
  --include-constant MAGIC_APPLE \
  --include-constant MAGIC_EXTENSION \
  --include-constant MAGIC_COMPRESS_TRANSP \
  --include-constant MAGIC_NO_COMPRESS_FORK \
  --include-constant MAGIC_NODESC \
  --include-constant MAGIC_NO_CHECK_COMPRESS \
  --include-constant MAGIC_NO_CHECK_TAR \
  --include-constant MAGIC_NO_CHECK_SOFT \
  --include-constant MAGIC_NO_CHECK_APPTYPE \
  --include-constant MAGIC_NO_CHECK_ELF \
  --include-constant MAGIC_NO_CHECK_TEXT \
  --include-constant MAGIC_NO_CHECK_CDF \
  --include-constant MAGIC_NO_CHECK_CSV \
  --include-constant MAGIC_NO_CHECK_TOKENS \
  --include-constant MAGIC_NO_CHECK_ENCODING \
  --include-constant MAGIC_NO_CHECK_JSON \
  --include-constant MAGIC_NO_CHECK_SIMH \
  --include-constant MAGIC_NO_CHECK_BUILTIN \
  --include-constant MAGIC_NO_CHECK_ASCII \
  --include-constant MAGIC_NO_CHECK_FORTRAN \
  --include-constant MAGIC_NO_CHECK_TROFF \
  --include-constant MAGIC_VERSION \
  --include-constant MAGIC_PARAM_INDIR_MAX \
  --include-constant MAGIC_PARAM_NAME_MAX \
  --include-constant MAGIC_PARAM_ELF_PHNUM_MAX \
  --include-constant MAGIC_PARAM_ELF_SHNUM_MAX \
  --include-constant MAGIC_PARAM_ELF_NOTES_MAX \
  --include-constant MAGIC_PARAM_REGEX_MAX \
  --include-constant MAGIC_PARAM_BYTES_MAX \
  --include-constant MAGIC_PARAM_ENCODING_MAX \
  --include-constant MAGIC_PARAM_ELF_SHSIZE_MAX \
  --include-constant MAGIC_PARAM_MAGWARN_MAX \
  "$ROOT/jextract/libmagic_api.h"

perl -0777 -pi -e \
  's/static final SymbolLookup SYMBOL_LOOKUP = .*?;/static final SymbolLookup SYMBOL_LOOKUP = io.github.ghosthack.libmagicffm.LibMagicLibs.lookup();/s' \
  "$GEN_DIR/LibMagic.java"

if grep -rn "$PREFIX" "$GEN_DIR" >/dev/null; then
  echo "ERROR: build-prefix paths survived in generated stubs"; exit 1
fi
grep -q 'LibMagicLibs.lookup()' "$GEN_DIR/LibMagic.java" \
  || { echo "ERROR: lookup patch did not apply"; exit 1; }

echo "Generated $(ls "$GEN_DIR" | wc -l | tr -d ' ') files into $GEN_DIR"
