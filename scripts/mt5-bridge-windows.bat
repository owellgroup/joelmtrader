@echo off
REM Bridge from the cloud Python engine to the MT5 desktop on this PC.
REM 1. Open MetaTrader 5 and log in. Algo Trading must be green.
REM 2. Double-click this file and leave the window open.
cd /d "%~dp0"
where python >nul 2>&1
if errorlevel 1 (
  echo Install Python 3 from python.org and tick "Add python.exe to PATH".
  pause
  exit /b 1
)
if not exist .venv-bridge (
  python -m venv .venv-bridge
)
call .venv-bridge\Scripts\activate.bat
python -m pip install --upgrade pip
pip install "MetaTrader5>=5.0.45" "rpyc>=5.3.1,<7" "numpy>=1.26,<3"
echo.
echo --------------------------------------------------------------
echo  Put this public IP in Dokploy as MT5_RPYC_HOST
echo  Put 18812 in Dokploy as MT5_RPYC_PORT
powershell -NoProfile -Command "try { '  ' + (Invoke-RestMethod -Uri https://api.ipify.org -TimeoutSec 15) } catch { '  Could not look it up. In a browser on this PC, search: what is my ip' }"
echo --------------------------------------------------------------
echo.
echo Leave this window open. Leave MetaTrader 5 open and logged in.
echo.
python mt5_bridge.py
pause
