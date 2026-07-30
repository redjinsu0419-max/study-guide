@echo off
chcp 65001 >nul
setlocal
cd /d "%~dp0"

echo.
echo =========================================
echo       공부 가이드 APK 만들기
echo =========================================
echo.

where flutter >nul 2>nul
if errorlevel 1 (
  echo [오류] Flutter가 설치되어 있지 않거나 PATH에 등록되지 않았습니다.
  echo Android Studio와 Flutter를 설치한 뒤 다시 실행해 주세요.
  echo https://docs.flutter.dev/get-started/install/windows/mobile
  pause
  exit /b 1
)

if not exist "android\app\google-services.json" (
  echo [오류] google-services.json 파일이 없습니다.
  echo 가지고 있는 파일을 android\app 폴더에 넣어 주세요.
  pause
  exit /b 1
)

:check_config
if not exist "lib\config\app_config.dart" (
  copy /y "lib\config\app_config.example.dart" "lib\config\app_config.dart" >nul
)

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$text = Get-Content -Raw 'lib\config\app_config.dart'; if ($text -match 'https://PASTE_' -or $text -notmatch 'https://[A-Za-z0-9.-]+\.workers\.dev') { exit 1 }"
if errorlevel 1 (
  echo [확인 필요] Cloudflare Worker 주소를 입력해야 합니다.
  echo app_config.dart의 backendBaseUrl을 실제 workers.dev 주소로 바꿔 주세요.
  start "" notepad "lib\config\app_config.dart"
  pause
  goto check_config
)

echo [1/3] 필요한 패키지를 받는 중...
call flutter pub get
if errorlevel 1 goto failed

echo [2/3] 자동 테스트 중...
call flutter test
if errorlevel 1 goto failed

echo [3/3] 안드로이드 APK를 만드는 중...
call flutter build apk --release
if errorlevel 1 goto failed

copy /y "build\app\outputs\flutter-apk\app-release.apk" "공부_가이드.apk" >nul
echo.
echo [완료] 이 폴더에 공부_가이드.apk 파일을 만들었습니다.
start "" explorer /select,"%~dp0공부_가이드.apk"
pause
exit /b 0

:failed
echo.
echo [실패] 위에 표시된 오류 내용을 확인해 주세요.
pause
exit /b 1
