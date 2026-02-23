#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK_DIR="${WORK_DIR:-$ROOT_DIR/.work}"
LUAJIT_DIR="${LUAJIT_DIR:-$WORK_DIR/LuaJIT}"
LUAJIT_REF="${LUAJIT_REF:-v2.1}"
TARGET_ARCH="${TARGET_ARCH:-x64}"

case "$TARGET_ARCH" in
  win32)
    export PATH="/mingw32/bin:$PATH"
    CROSS="${CROSS:-}"
    CC_BIN="${CC:-gcc}"
    HOST_CC="${HOST_CC:-gcc -m32}"
    TARGET_FLAGS_DEFAULT=""
    ;;
  x64)
    export PATH="/mingw64/bin:$PATH"
    CROSS="${CROSS:-}"
    CC_BIN="${CC:-gcc}"
    HOST_CC="${HOST_CC:-gcc}"
    TARGET_FLAGS_DEFAULT=""
    ;;
  arm64)
    export PATH="/mingw64/bin:$PATH"
    CROSS="${CROSS:-}"
    CC_BIN="${CC:-clang}"
    HOST_CC="${HOST_CC:-gcc}"
    TARGET_FLAGS_DEFAULT="--target=aarch64-w64-windows-gnu"
    ;;
  *)
    echo "Unsupported TARGET_ARCH: $TARGET_ARCH (expected: win32, x64, arm64)" >&2
    exit 1
    ;;
esac

mkdir -p "$WORK_DIR"
if [ ! -d "$LUAJIT_DIR/.git" ]; then
  git clone --depth 1 --branch "$LUAJIT_REF" https://github.com/LuaJIT/LuaJIT "$LUAJIT_DIR"
fi

cp "$ROOT_DIR/src/utf8_wrappers.c" "$LUAJIT_DIR/src/utf8_wrappers.c"
cp "$ROOT_DIR/src/utf8_wrappers.h" "$LUAJIT_DIR/src/utf8_wrappers.h"

TARGET_CC_BIN="${CROSS}${CC_BIN}"
if ! command -v "$TARGET_CC_BIN" >/dev/null 2>&1; then
  echo "Compiler not found: $TARGET_CC_BIN" >&2
  exit 1
fi

if [ -n "$CROSS" ] && command -v "${CROSS}strip" >/dev/null 2>&1; then
  TARGET_STRIP_BIN="${CROSS}strip"
elif command -v strip >/dev/null 2>&1; then
  TARGET_STRIP_BIN="strip"
elif command -v llvm-strip >/dev/null 2>&1; then
  TARGET_STRIP_BIN="llvm-strip"
else
  echo "Error: strip tool not found (tried: ${CROSS}strip, strip, llvm-strip)." >&2
  exit 1
fi

if ! grep -Eq 'lib_buffer\.o[[:space:]]+utf8_wrappers\.o' "$LUAJIT_DIR/src/Makefile"; then
  perl -0777 -i -pe 's/(lib_buffer\.o)([ \t]*\r?\nLJLIB_C=)/$1 utf8_wrappers.o$2/' "$LUAJIT_DIR/src/Makefile"
  if ! grep -Eq 'lib_buffer\.o[[:space:]]+utf8_wrappers\.o' "$LUAJIT_DIR/src/Makefile"; then
    echo "Failed to update LuaJIT src/Makefile with utf8_wrappers.o" >&2
    exit 1
  fi
fi

if [ "${PREPARE_ONLY:-0}" = "1" ]; then
  echo "Prepared LuaJIT sources in $LUAJIT_DIR"
  exit 0
fi

# Avoid leaking external TARGET_ARCH env into LuaJIT Makefile internals.
make -C "$LUAJIT_DIR/src" \
  CC="$CC_BIN" \
  HOST_CC="$HOST_CC" \
  CROSS="$CROSS" \
  TARGET_FLAGS="${TARGET_FLAGS:-$TARGET_FLAGS_DEFAULT}" \
  TARGET_SYS=Windows \
  TARGET_CFLAGS="${TARGET_CFLAGS:-} -include utf8_wrappers.h" \
  TARGET_STRIP="$TARGET_STRIP_BIN" \
  TARGET_ARCH= \
  "$@"
