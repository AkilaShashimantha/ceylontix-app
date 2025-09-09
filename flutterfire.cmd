@echo off
setlocal
set FF_PATH=%LOCALAPPDATA%\Pub\Cache\bin\flutterfire.bat
if exist "%FF_PATH%" (
  call "%FF_PATH%" %*
) else (
  echo flutterfire.bat not found at %FF_PATH%
  echo Please run: dart pub global activate flutterfire_cli
  exit /b 1
)
