# LuaJIT Unicode for Windows

This is an adaptation of https://github.com/Lekensteyn/lua-unicode to work
under LuaJIT and for the purpose of **Pragtical Code Editor**.

## Build integration without editing LuaJIT sources manually

This repository now provides standalone scripts that:

1. download LuaJIT sources automatically;
2. copy `utf8_wrappers.{c,h}` into LuaJIT `src/`;
3. apply patch files automatically;
4. run LuaJIT native build scripts for each toolchain.

## Implementation options analysis

### Option 1: Keep manual patching (old approach)
- **Pros:** trivial maintenance in this repository.
- **Cons:** easy to make mistakes, not reproducible, requires hand-editing LuaJIT sources every time.

### Option 2: Override everything only with compiler flags
- **Pros:** no source patch files.
- **Cons:** brittle for LuaJIT internals, hard to inject `utf8_wrappers.c` into both GNU Make and `msvcbuild.bat` flows, harder to support all targets consistently.

### Option 3 (implemented): Patch-based automation wrapper
- **Pros:** reproducible, explicit, works with upstream LuaJIT build logic, no manual edits in LuaJIT tree, supports separate MinGW/MSVC workflows.
- **Cons:** patch files may need refresh if upstream LuaJIT layout changes.

## Files

- `patches/luajit-luaconf-unicode.patch`
- `patches/luajit-makefile-unicode.patch` (MinGW/GNU Make flow)
- `patches/luajit-msvcbuild-unicode.patch` (MSVC flow)
- `scripts/build-mingw.sh`
- `scripts/build-msvc.bat`

## MinGW usage

```bash
TARGET_ARCH=x64 ./scripts/build-mingw.sh
```

Ready-to-run commands for each target:

```bash
# Win32
TARGET_ARCH=win32 ./scripts/build-mingw.sh

# x64
TARGET_ARCH=x64 ./scripts/build-mingw.sh

# ARM64
TARGET_ARCH=arm64 ./scripts/build-mingw.sh
```

Supported `TARGET_ARCH` values:
- `win32` (i686 toolchain)
- `x64` (x86_64 toolchain)
- `arm64` (aarch64 toolchain)

Useful variables:
- `LUAJIT_REF` (default: `v2.1`)
- `WORK_DIR` (default: `.work`)
- `LUAJIT_DIR` (default: `$WORK_DIR/LuaJIT`)
- `PREPARE_ONLY=1` (download + patch, no build)

## MSVC usage

Open the appropriate Visual Studio command prompt for target architecture
(`x86`, `x64`, or `arm64`) and run:

```bat
set TARGET_ARCH=x64
scripts\build-msvc.bat
```

Ready-to-run commands for each target:

```bat
:: Win32
set TARGET_ARCH=win32
scripts\build-msvc.bat

:: x64
set TARGET_ARCH=x64
scripts\build-msvc.bat

:: ARM64
set TARGET_ARCH=arm64
scripts\build-msvc.bat
```

Supported `TARGET_ARCH` values:
- `win32`
- `x64`
- `arm64`

Useful variables:
- `LUAJIT_REF` (default: `v2.1`)
- `WORK_DIR` (default: `.work`)
- `LUAJIT_DIR` (default: `%WORK_DIR%\LuaJIT`)
- `PREPARE_ONLY=1` (download + patch, no build)
