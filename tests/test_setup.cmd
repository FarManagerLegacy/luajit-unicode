@echo off
setlocal
chcp 65001 >nul

set "DIR=tests\_unicode_fixture"
rem Default expected LuaJIT DLL output path from wrapper build scripts.
rem CI can override LUAJIT_DLL when artifacts are placed somewhere else.
rem For LUAJIT_DLL overrides, PowerShell accepts both '\' and '/' separators.
if "%LUAJIT_DLL%"=="" set "LUAJIT_DLL=.work\LuaJIT\src\lua51.dll"

rmdir /s /q "%DIR%" 2>nul
if exist "%DIR%" exit /b 1
mkdir "%DIR%" || exit /b 1

rem Use a single -Command argument; split quoted arguments are not executed by PowerShell as one script.
rem Sample fixture name: Ελλ_中文_한국_عربي_кирил_देवनागरी.
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$ErrorActionPreference='Stop'; $dir='tests/_unicode_fixture'; $codes=@(0x395,0x3bb,0x3bb,0x5f,0x4e2d,0x6587,0x5f,0xd55c,0xad6d,0x5f,0x639,0x631,0x628,0x64a,0x5f,0x43a,0x438,0x440,0x438,0x43b,0x5f,0x926,0x947,0x935,0x928,0x93e,0x917,0x930,0x940); $name = -join ($codes | ForEach-Object { [char]$_ }); if ($name.Length -ne $codes.Length) { throw 'Failed to build Unicode fixture name' }; $dll=$env:LUAJIT_DLL; Set-Content -LiteralPath (Join-Path $dir ($name + '.txt')) -Value 'fixture-content' -Encoding UTF8; Set-Content -LiteralPath (Join-Path $dir ($name + '.lua')) -Value 'return ''lua-fixture-ok''' -Encoding UTF8; Set-Content -LiteralPath (Join-Path $dir ('rename_src_' + $name + '.txt')) -Value 'rename-source' -Encoding UTF8; $cdir = Join-Path $dir ('lib_' + $name); New-Item -ItemType Directory -Path $cdir -Force | Out-Null; Copy-Item $dll (Join-Path $cdir 'jitmod.dll') -Force; Set-Content -LiteralPath (Join-Path $dir 'fixture_name.txt') -Value $name -Encoding UTF8; Set-Content -LiteralPath (Join-Path $dir 'setup_done.txt') -Value 'ok' -Encoding ASCII;"
if errorlevel 1 exit /b 1

exit /b 0
