@echo off
setlocal
chcp 65001 >nul

set "DIR=tests\_unicode_fixture"
set "NAME=Ελλ_中文_한국_عربي_кирил_देवनागरी"
rem Default expected LuaJIT DLL output path from wrapper build scripts.
rem CI can override LUAJIT_DLL when artifacts are placed somewhere else.
if "%LUAJIT_DLL%"=="" set "LUAJIT_DLL=.work\LuaJIT\src\lua51.dll"

rmdir /s /q "%DIR%" 2>nul
if exist "%DIR%" exit /b 1
mkdir "%DIR%" || exit /b 1

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$ErrorActionPreference='Stop';" ^
  "$dir='tests/_unicode_fixture';" ^
  "$name='Ελλ_中文_한국_عربي_кирил_देवनागरी';" ^
  "$dll=$env:LUAJIT_DLL;" ^
  "Set-Content -LiteralPath (Join-Path $dir ($name + '.txt')) -Value 'fixture-content' -Encoding UTF8;" ^
  "Set-Content -LiteralPath (Join-Path $dir ($name + '.lua')) -Value 'return ''lua-fixture-ok''' -Encoding UTF8;" ^
  "Set-Content -LiteralPath (Join-Path $dir ('rename_src_' + $name + '.txt')) -Value 'rename-source' -Encoding UTF8;" ^
  "$cdir = Join-Path $dir ('lib_' + $name); New-Item -ItemType Directory -Path $cdir -Force | Out-Null;" ^
  "Copy-Item $dll (Join-Path $cdir 'jitmod.dll') -Force;" ^
  "Set-Content -LiteralPath (Join-Path $dir 'setup_done.txt') -Value 'ok' -Encoding ASCII;"
if errorlevel 1 exit /b 1

exit /b 0
