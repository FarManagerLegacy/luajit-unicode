#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK_DIR="${WORK_DIR:-$ROOT_DIR/.work}"
LUAJIT_DIR="${LUAJIT_DIR:-$WORK_DIR/LuaJIT}"
LUAJIT_REF="${LUAJIT_REF:-v2.1}"
TARGET_ARCH="${TARGET_ARCH:-x64}"

case "$TARGET_ARCH" in
  win32)
    CROSS="${CROSS:-i686-w64-mingw32-}"
    HOST_CC="${HOST_CC:-gcc -m32}"
    ;;
  x64)
    CROSS="${CROSS:-x86_64-w64-mingw32-}"
    HOST_CC="${HOST_CC:-gcc}"
    ;;
  arm64)
    CROSS="${CROSS:-aarch64-w64-mingw32-}"
    HOST_CC="${HOST_CC:-gcc}"
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

echo "[diag] gcc predefined architecture macros (host gcc)"
HOST_GCC_BIN="${CC:-gcc}"
echo | "$HOST_GCC_BIN" -dM -E - | grep -E "__x86_64__|__i386__|__ARM|__aarch64__" || true
echo "[diag] gcc target help (host gcc)"
"$HOST_GCC_BIN" --help=target | grep -A2 "march" || true

CC_BIN="${CROSS}gcc"
echo "[diag] toolchain compiler: $CC_BIN"
if command -v "$CC_BIN" >/dev/null 2>&1; then
  echo | "$CC_BIN" -dM -E - | grep -E "__x86_64__|__i386__|__ARM|__aarch64__" || true
  "$CC_BIN" --help=target | grep -A2 "march" || true
fi

STRIP_BIN="${CROSS}strip"
if command -v "$STRIP_BIN" >/dev/null 2>&1; then
  echo "[diag] strip tool: $STRIP_BIN"
  "$STRIP_BIN" --version | head -n 1 || true
  TARGET_STRIP_BIN="$STRIP_BIN"
else
  echo "[diag] strip tool not found: $STRIP_BIN, fallback to strip"
  if ! command -v strip >/dev/null 2>&1; then
    echo "[diag] strip tool not found. Install binutils or ensure strip is in PATH." >&2
    exit 1
  fi
  echo "[diag] fallback strip tool: $(command -v strip)"
  strip --version | head -n 1 || true
  TARGET_STRIP_BIN="strip"
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

make -C "$LUAJIT_DIR/src" \
  HOST_CC="$HOST_CC" \
  CROSS="$CROSS" \
  TARGET_SYS=Windows \
  TARGET_CFLAGS="${TARGET_CFLAGS:-} -include utf8_wrappers.h" \
  TARGET_STRIP="$TARGET_STRIP_BIN" \
  TARGET_ARCH= \
  "$@"
