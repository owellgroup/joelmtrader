@echo off
REM Runs the Spring Boot API on Windows (needs JDK 17+ and Maven in PATH).
cd /d "%~dp0\.."
if not exist .env ( echo Create .env first: copy .env.example .env & pause & exit /b 1 )
for /f "usebackq eol=# tokens=1,* delims==" %%a in (".env") do set "%%a=%%b"
set ENGINE_URL=http://localhost:8000
cd api
mvn -q spring-boot:run
pause
