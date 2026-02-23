@echo off
setlocal
chcp 65001 >nul

set "DIR=tests\_unicode_fixture"
set "NAME=Ελλ_中文_한국_عربي_кирил_देवनागरी"
set "BASE=%DIR%\%NAME%"

rmdir /s /q "%DIR%" 2>nul
if exist "%DIR%" exit /b 1
mkdir "%DIR%" || exit /b 1

> "%BASE%.txt" echo fixture-content
> "%BASE%.lua" echo return 'lua-fixture-ok'
> "%BASE%_rename_src.txt" echo rename-source
> "%BASE%_loadlib_stub.dll" echo not-a-dll
> "%DIR%\fixture_name.txt" echo %NAME%
> "%DIR%\setup_done.txt" echo ok

exit /b 0
