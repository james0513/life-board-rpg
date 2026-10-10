@echo off
chcp 65001 >nul
cd /d "%~dp0"
echo 將開啟獨立驗收存檔，不會讀寫正式遊戲存檔。
where flutter >nul 2>nul
if errorlevel 1 (
  echo 找不到 Flutter。請先安裝 Flutter SDK 並加入 PATH。
  pause
  exit /b 1
)
call flutter pub get
if errorlevel 1 (
  echo 套件準備失敗，請保留上方第一段錯誤。
  pause
  exit /b 1
)
call flutter run -d chrome -t lib/main.dart --dart-define=LIFE_ACCEPTANCE=true
pause
