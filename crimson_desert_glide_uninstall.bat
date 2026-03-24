@echo off
setlocal

set "SCRIPT_DIR=%~dp0"
if "%SCRIPT_DIR:~-1%"=="\" set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"

set "DEFAULT_GAME_DIR="
call :find_default_game_dir

set "GAME_DIR=%~1"

if /I "%~1"=="/?" goto :usage
if /I "%~1"=="-h" goto :usage
if /I "%~1"=="--help" goto :usage

if defined GAME_DIR goto :cli_uninstall
goto :interactive

:interactive
cls
echo Crimson Desert Glide Uninstall
echo.
echo This restores the original default glide values.
echo If a backup exists, it will be restored.
echo If no backup exists, default bytes for 25 and 50 will be written directly.
echo.
echo Default Stamina Spent values:
echo   Normal glide Stamina Spent = 25
echo   Fast glide Stamina Spent   = 50
echo.
echo Folder instructions:
echo   Enter your Crimson Desert game folder path.
echo   If this BAT is inside the game's folder, just press Enter.
if defined DEFAULT_GAME_DIR (
  echo   Auto-detected folder: %DEFAULT_GAME_DIR%
) else (
  echo   Auto-detect did not find the game folder, so type it manually.
)
echo.

:prompt_game_dir
set "GAME_DIR="
if defined DEFAULT_GAME_DIR (
  set /p "GAME_DIR=Game folder path [%DEFAULT_GAME_DIR%]: "
  if not defined GAME_DIR set "GAME_DIR=%DEFAULT_GAME_DIR%"
) else (
  set /p "GAME_DIR=Game folder path: "
)
call :normalize_game_dir
if not defined GAME_DIR (
  echo.
  echo Please enter a valid Crimson Desert folder path.
  echo.
  goto :prompt_game_dir
)
if not exist "%GAME_DIR%\0008\0.paz" (
  echo.
  echo Could not find "%GAME_DIR%\0008\0.paz"
  echo Make sure the path points to your Crimson Desert folder.
  echo.
  goto :prompt_game_dir
)

echo.
set "CONFIRM="
set /p "CONFIRM=Continue with uninstall? [Y/N]: "
if /I "%CONFIRM%"=="Y" goto :run
if /I "%CONFIRM%"=="N" goto :finish
echo.
echo Invalid selection.
goto :interactive

:cli_uninstall
call :normalize_game_dir
if not defined GAME_DIR (
  if defined DEFAULT_GAME_DIR (
    set "GAME_DIR=%DEFAULT_GAME_DIR%"
  ) else (
    echo.
    echo Could not auto-detect the game folder.
    echo Pass the Crimson Desert folder path explicitly.
    goto :usage_error
  )
)
if not exist "%GAME_DIR%\0008\0.paz" (
  echo.
  echo Could not find "%GAME_DIR%\0008\0.paz"
  echo Make sure the path points to your Crimson Desert folder.
  goto :finish
)
goto :run

:find_default_game_dir
if exist "%SCRIPT_DIR%\0008\0.paz" (
  set "DEFAULT_GAME_DIR=%SCRIPT_DIR%"
  exit /b 0
)

for %%D in (C D E F G H I J K L M N O P Q R S T U V W X Y Z) do (
  if not defined DEFAULT_GAME_DIR if exist "%%D:\Program Files\Steam\steamapps\common\Crimson Desert\0008\0.paz" set "DEFAULT_GAME_DIR=%%D:\Program Files\Steam\steamapps\common\Crimson Desert"
  if not defined DEFAULT_GAME_DIR if exist "%%D:\Steam\steamapps\common\Crimson Desert\0008\0.paz" set "DEFAULT_GAME_DIR=%%D:\Steam\steamapps\common\Crimson Desert"
  if not defined DEFAULT_GAME_DIR if exist "%%D:\SteamLibrary\steamapps\common\Crimson Desert\0008\0.paz" set "DEFAULT_GAME_DIR=%%D:\SteamLibrary\steamapps\common\Crimson Desert"
)
exit /b 0

:normalize_game_dir
set "GAME_DIR=%GAME_DIR:"=%"
if "%GAME_DIR:~-1%"=="\" set "GAME_DIR=%GAME_DIR:~0,-1%"
exit /b 0

:run
set "CD_GLIDE_GAME_DIR=%GAME_DIR%"

echo.
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$ErrorActionPreference = 'Stop'; try {" ^
  "  $gameDir = $env:CD_GLIDE_GAME_DIR;" ^
  "  $pazPath = Join-Path $gameDir '0008\0.paz';" ^
  "  $backupPath = Join-Path (Split-Path -Parent $pazPath) '0.paz.glide_patcher_backup';" ^
  "  $baseOffset = 0x00CCDF9E;" ^
  "  $fastOffset = 0x00CCBD2B;" ^
  "  $defaultBase = [byte[]](0x58,0x9E);" ^
  "  $defaultFast = [byte[]](0xB0,0x3C);" ^
  "  function Write-Bytes([string]$path,[int]$offset,[byte[]]$bytes) { " ^
  "    $stream = [System.IO.File]::Open($path, [System.IO.FileMode]::Open, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::Read);" ^
  "    try { $stream.Seek($offset, [System.IO.SeekOrigin]::Begin) | Out-Null; $stream.Write($bytes, 0, $bytes.Length) } finally { $stream.Dispose() };" ^
  "  };" ^
  "  function Read-Bytes([string]$path,[int]$offset,[int]$count) { " ^
  "    $stream = [System.IO.File]::Open($path, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite);" ^
  "    try { $buffer = New-Object byte[] $count; $stream.Seek($offset, [System.IO.SeekOrigin]::Begin) | Out-Null; $read = $stream.Read($buffer, 0, $count); if ($read -ne $count) { throw 'Could not read verification bytes from the archive.' }; return $buffer } finally { $stream.Dispose() };" ^
  "  };" ^
  "  if (-not (Test-Path -LiteralPath $pazPath)) { throw ('Archive not found: ' + $pazPath) };" ^
  "  if (Test-Path -LiteralPath $backupPath) { Copy-Item -LiteralPath $backupPath -Destination $pazPath -Force; Write-Host ('Uninstalled: restored backup from ' + $backupPath) } else { Write-Bytes $pazPath $baseOffset $defaultBase; Write-Bytes $pazPath $fastOffset $defaultFast; Write-Host 'Uninstalled: backup not found, restored default glide values directly.' };" ^
  "  $currentBase = Read-Bytes $pazPath $baseOffset 2;" ^
  "  $currentFast = Read-Bytes $pazPath $fastOffset 2;" ^
  "  Write-Host ('Bytes now:     normal=' + ([System.BitConverter]::ToString($currentBase).Replace('-', ' ')) + ' fast=' + ([System.BitConverter]::ToString($currentFast).Replace('-', ' ')));" ^
  "} catch { [Console]::Error.WriteLine($_.Exception.Message); exit 1 }"

if errorlevel 1 (
  echo.
  echo Uninstall failed.
) else (
  echo.
  echo Uninstall complete.
)

goto :finish

:usage_error
echo.

:usage
echo Usage:
echo   %~nx0
echo   %~nx0 "E:\Program Files\Steam\steamapps\common\Crimson Desert"
echo   %~nx0 "D:\SteamLibrary\steamapps\common\Crimson Desert"

:finish
set "FINAL_EXIT_CODE=%ERRORLEVEL%"
echo.
set "PRESS_ENTER="
set /p "PRESS_ENTER=Press Enter to close this window..."
exit /b %FINAL_EXIT_CODE%
