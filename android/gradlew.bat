@echo off
setlocal
set "GRADLE_VERSION=8.11.1"
set "SCRIPT_DIR=%~dp0"
set "BOOTSTRAP_DIR=%SCRIPT_DIR%.gradle-bootstrap"
set "INSTALL_DIR=%BOOTSTRAP_DIR%\gradle-%GRADLE_VERSION%"
set "ZIP_PATH=%BOOTSTRAP_DIR%\gradle-%GRADLE_VERSION%-bin.zip"

if exist "%INSTALL_DIR%\bin\gradle.bat" goto run

if not exist "%BOOTSTRAP_DIR%" mkdir "%BOOTSTRAP_DIR%"
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$ProgressPreference='SilentlyContinue'; Invoke-WebRequest -UseBasicParsing -Uri 'https://services.gradle.org/distributions/gradle-%GRADLE_VERSION%-bin.zip' -OutFile '%ZIP_PATH%'"
if errorlevel 1 exit /b 1

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "Expand-Archive -LiteralPath '%ZIP_PATH%' -DestinationPath '%BOOTSTRAP_DIR%' -Force"
if errorlevel 1 exit /b 1

:run
call "%INSTALL_DIR%\bin\gradle.bat" %*
exit /b %errorlevel%

