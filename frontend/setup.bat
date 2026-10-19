@echo off
REM One-time: generate the platform folders (windows/web/android) around the provided lib\ code.
cd /d "%~dp0"
call flutter create --project-name waya_fx_bot --org com.wayaspot --platforms=windows,web,android .
call flutter pub get
echo.
echo Done. Run:  flutter run -d windows     (or: flutter run -d chrome)
pause
