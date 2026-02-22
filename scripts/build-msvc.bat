@echo off
setlocal

set "ROOT_DIR=%~dp0.."
for %%I in ("%ROOT_DIR%") do set "ROOT_DIR=%%~fI"

if "%WORK_DIR%"=="" set "WORK_DIR=%ROOT_DIR%\.work"
if "%LUAJIT_DIR%"=="" set "LUAJIT_DIR=%WORK_DIR%\LuaJIT"
if "%LUAJIT_REF%"=="" set "LUAJIT_REF=v2.1"

if "%TARGET_ARCH%"=="" set "TARGET_ARCH=x64"
if /I not "%TARGET_ARCH%"=="win32" if /I not "%TARGET_ARCH%"=="x64" if /I not "%TARGET_ARCH%"=="arm64" (
  echo Unsupported TARGET_ARCH: %TARGET_ARCH% ^(expected: win32, x64, arm64^)
  exit /b 1
)
if /I "%TARGET_ARCH%"=="win32" set "VS_ARCH=x86"
if /I "%TARGET_ARCH%"=="x64" set "VS_ARCH=x64"
if /I "%TARGET_ARCH%"=="arm64" set "VS_ARCH=arm64"

if not exist "%WORK_DIR%" mkdir "%WORK_DIR%"
if not exist "%LUAJIT_DIR%\.git" (
  git clone --depth 1 --branch "%LUAJIT_REF%" https://github.com/LuaJIT/LuaJIT "%LUAJIT_DIR%"
  if errorlevel 1 exit /b 1
)

copy /Y "%ROOT_DIR%\src\utf8_wrappers.c" "%LUAJIT_DIR%\src\utf8_wrappers.c" >nul
if errorlevel 1 exit /b 1
copy /Y "%ROOT_DIR%\src\utf8_wrappers.h" "%LUAJIT_DIR%\src\utf8_wrappers.h" >nul
if errorlevel 1 exit /b 1

call :APPLY_PATCH "%ROOT_DIR%\patches\luajit-luaconf-unicode.patch"
if errorlevel 1 exit /b 1
call :APPLY_PATCH "%ROOT_DIR%\patches\luajit-msvcbuild-unicode.patch"
if errorlevel 1 exit /b 1

if "%PREPARE_ONLY%"=="1" (
  echo Prepared LuaJIT sources in %LUAJIT_DIR%
  exit /b 0
)

if not defined VSINSTALLDIR (
  echo Visual Studio build environment is not initialized.
  echo Run this script from a Visual Studio Command Prompt.
  exit /b 1
)

call "%VSINSTALLDIR%Common7\Tools\VsDevCmd.bat" -arch=%VS_ARCH% -no_logo
if errorlevel 1 exit /b 1

pushd "%LUAJIT_DIR%\src"
call msvcbuild.bat %*
set "BUILD_RC=%ERRORLEVEL%"
popd

exit /b %BUILD_RC%

:APPLY_PATCH
set "PATCH_FILE=%~1"
git -C "%LUAJIT_DIR%" apply --reverse --check "%PATCH_FILE%" >nul 2>&1
if not errorlevel 1 (
  echo Patch already applied: %~nx1
  exit /b 0
)

git -C "%LUAJIT_DIR%" apply "%PATCH_FILE%"
if errorlevel 1 (
  echo Failed to apply patch: %PATCH_FILE%
  exit /b 1
)
exit /b 0
