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
if /I "%TARGET_ARCH%"=="win32" set "VCVARS_ARCH=x86"
if /I "%TARGET_ARCH%"=="x64" set "VCVARS_ARCH=x64"
if /I "%TARGET_ARCH%"=="arm64" set "VCVARS_ARCH=amd64_arm64"

if not exist "%WORK_DIR%" mkdir "%WORK_DIR%"
if not exist "%LUAJIT_DIR%\.git" (
  git clone --depth 1 --branch "%LUAJIT_REF%" https://github.com/LuaJIT/LuaJIT "%LUAJIT_DIR%"
  if errorlevel 1 exit /b 1
)

copy /Y "%ROOT_DIR%\src\utf8_wrappers.c" "%LUAJIT_DIR%\src\utf8_wrappers.c" >nul
if errorlevel 1 exit /b 1
copy /Y "%ROOT_DIR%\src\utf8_wrappers.h" "%LUAJIT_DIR%\src\utf8_wrappers.h" >nul
if errorlevel 1 exit /b 1

call :APPLY_PATCH "%ROOT_DIR%\patches\luajit-msvcbuild-unicode.patch"
if errorlevel 1 exit /b 1

if "%PREPARE_ONLY%"=="1" (
  echo Prepared LuaJIT sources in %LUAJIT_DIR%
  exit /b 0
)

if not defined VSINSTALLDIR call :RESOLVE_VSINSTALLDIR
if errorlevel 1 exit /b 1
if not "%VSINSTALLDIR:~-1%"=="\" set "VSINSTALLDIR=%VSINSTALLDIR%\"

set "VCVARSALL=%VSINSTALLDIR%VC\Auxiliary\Build\vcvarsall.bat"
if not exist "%VCVARSALL%" (
  echo Failed to locate vcvarsall.bat under VSINSTALLDIR=%VSINSTALLDIR%
  exit /b 1
)

call "%VCVARSALL%" %VCVARS_ARCH%
if errorlevel 1 exit /b 1
where cl >nul 2>&1
if errorlevel 1 (
  echo MSVC compiler tools are not available after environment initialization.
  exit /b 1
)

rem Force wrapper header for all C translation units compiled by msvcbuild.bat.
rem Wrapper macros only activate in lib_* units where corresponding defines are present.
set "CL=/FIutf8_wrappers.h /I. %CL%"
rem Required for newer MSVC/UCRT toolchains when wide stdio helpers are linked.
set "LINK=legacy_stdio_definitions.lib ucrt.lib %LINK%"

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

:RESOLVE_VSINSTALLDIR
set "VSW=%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe"
if not exist "%VSW%" (
  echo vswhere.exe not found: %VSW%
  exit /b 1
)
set "VS_PATH="
for /f "usebackq tokens=*" %%i in (`"%VSW%" -latest -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath`) do (
  set "VS_PATH=%%i"
)
if "%VS_PATH%"=="" (
  echo Unable to locate Visual Studio installation with VC tools ^
(vswhere returned no matching path).
  exit /b 1
)
set "VSINSTALLDIR=%VS_PATH%"
if not "%VSINSTALLDIR:~-1%"=="\" set "VSINSTALLDIR=%VSINSTALLDIR%\"
exit /b 0
