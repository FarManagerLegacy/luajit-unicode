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

apply_patch_once() {
  local patch_file="$1"
  if git -C "$LUAJIT_DIR" apply --reverse --check "$patch_file" >/dev/null 2>&1; then
    echo "Patch already applied: $(basename "$patch_file")"
  else
    if ! git -C "$LUAJIT_DIR" apply "$patch_file"; then
      echo "Failed to apply patch: $patch_file" >&2
      exit 1
    fi
  fi
}

apply_patch_once "$ROOT_DIR/patches/luajit-makefile-unicode.patch"

if [ "${PREPARE_ONLY:-0}" = "1" ]; then
  echo "Prepared LuaJIT sources in $LUAJIT_DIR"
  exit 0
fi

make -C "$LUAJIT_DIR/src" \
  HOST_CC="$HOST_CC" \
  CROSS="$CROSS" \
  TARGET_SYS=Windows \
  TARGET_CFLAGS="${TARGET_CFLAGS:-} -include utf8_wrappers.h" \
  "$@"
