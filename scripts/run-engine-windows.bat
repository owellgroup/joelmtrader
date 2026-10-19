@echo off
REM Optional. Runs the whole Python engine on this PC, next to the MT5 desktop.
REM The normal setup leaves the engine on the server and only runs mt5-bridge-windows.bat here.
REM Usage: double-click, or run from the "backend" folder:  scripts\run-engine-windows.bat
cd /d "%~dp0\.."
if not exist .env ( echo Create .env first: copy .env.example .env & pause & exit /b 1 )
for /f "usebackq eol=# tokens=1,* delims==" %%a in (".env") do set "%%a=%%b"
REM Windows talks to the local API on localhost, and the engine data lives in .\engine\data
set JAVA_EVENTS_URL=http://145.241.187.174:8080/internal/events
set DATA_DIR=%CD%\engine\data
cd engine
if not exist .venv ( python -m venv .venv )
call .venv\Scripts\activate.bat
python -m pip install --upgrade pip >nul
pip install -r requirements.txt
echo.
echo Engine starting on http://localhost:8000  (BROKER_MODE=%BROKER_MODE%)
uvicorn app.main:app --host 0.0.0.0 --port 8000
pause
