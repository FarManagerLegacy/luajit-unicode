# LuaJIT Unicode for Windows

This is an adaptation of https://github.com/Lekensteyn/lua-unicode to work
under LuaJIT and for the purpose of **Pragtical Code Editor**.

## Build integration without editing LuaJIT sources manually

This repository now provides standalone scripts that:

1. download LuaJIT sources automatically;
2. copy `utf8_wrappers.{c,h}` into LuaJIT `src/`;
3. force-include `utf8_wrappers.h` via compiler flags;
4. apply minimal patch files only where extra objects need to be added;
5. run LuaJIT native build scripts for each toolchain.

## Implementation options analysis

### Option 1: Keep manual patching (old approach)
- **Pros:** trivial maintenance in this repository.
- **Cons:** easy to make mistakes, not reproducible, requires hand-editing LuaJIT sources every time.

### Option 2: Override everything only with compiler flags
- **Pros:** no source patch files.
- **Cons:** brittle for LuaJIT internals, hard to inject `utf8_wrappers.c` into both GNU Make and `msvcbuild.bat` flows, harder to support all targets consistently.

### Option 3 (implemented): Hybrid wrapper (forced include + minimal patches)
- **Pros:** reproducible, avoids patching `luaconf.h`, keeps patch scope smaller, supports separate MinGW/MSVC workflows.
- **Cons:** object list integration is still patched in upstream build scripts.

## Files

- `patches/luajit-makefile-unicode.patch` (MinGW/GNU Make flow)
- `patches/luajit-msvcbuild-unicode.patch` (MSVC flow)
- `scripts/build-mingw.sh`
- `scripts/build-msvc.bat`

## Imported-symbol audit (Windows)

Based on the current LuaJIT import list, the path/command/environment APIs that
need UTF-8 adaptation are already covered in `utf8_wrappers`:

- `fopen` / `freopen`
- `remove`
- `rename`
- `_popen`
- `system`
- `getenv`
- `GetModuleFileNameA`
- `LoadLibraryExA`

Most other imported symbols from the list are math/runtime/threading/memory APIs
or descriptor-level file APIs (`_write`, `_lseeki64`, `_fileno`, etc.) that do
not accept path strings and therefore do not need Unicode path wrappers.

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

## CI and releases

- PR CI builds patched LuaJIT on Windows for MinGW/MSVC and runs UTF-8 wrapper tests
  for runnable targets (`win32`, `x64`).
- MinGW ARM64 CI job is temporarily disabled due to current upstream LuaJIT ARM64 build
  incompatibility in this cross-build runner environment.
- MSVC ARM64 runtime tests are currently skipped in CI.
- Release workflow can be started manually (`workflow_dispatch`) with:
  - `luajit_ref` (LuaJIT ref to build from),
  - `release_tag` (tag for the GitHub Release),
  - `release_name` (optional release title).

Test file used in CI:
- `tests/test_utf8_wrappers.lua`
- Fixture setup script: `tests/test_setup.cmd`

### ARM/ARM64 build-and-test feasibility (analysis only)

- **MSVC ARM64 build:** works on `windows-latest` using `vcvarsall amd64_arm64`.
- **MSVC ARM64 runtime tests:** require reliable execution policy for ARM64 artifacts
  on the runner image and stable UTF-8 console/environment behavior. Kept disabled
  for now in CI to avoid blocking unrelated PRs.
- **MinGW ARM64 build:** can be driven with host clang cross-targeting
  (`--target=aarch64-w64-windows-gnu`) when x86_64 clang tools are installed.
- **MinGW ARM64 runtime tests:** not enabled yet; practical coverage needs either a
  native ARM64 Windows runner (preferred) or a validated emulation strategy.

## Upstream hook proposal (to remove local patches later)

Current LuaJIT build files do not expose extension points for adding external C
objects cleanly. Minimal upstream-compatible hooks that would allow patch-free integration:

1. `src/Makefile`:
   - add `EXTRA_TARGET_CFLAGS ?=`
   - add `EXTRA_LJLIB_O ?=`
   - append them to `TARGET_CFLAGS` and `LJLIB_O`.
2. `src/msvcbuild.bat`:
   - add optional env vars like `LJ_EXTRA_CFILES`, `LJ_EXTRA_OBJS`, `LJ_EXTRA_CFLAGS`
   - append them in compile/link commands.
3. Keep default behavior unchanged when these vars are not set.

With these hooks, this repository could switch to pure wrapper scripts without any
content patches to upstream files.
