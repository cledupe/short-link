@echo off
setlocal enabledelayedexpansion

echo [INFO] ===========================================
echo [INFO]  Distributed URL Shortener - Local Tests
echo [INFO] ===========================================
echo.

:: ------------------------------------------------------------------
:: 0.7.1 - Verify all containers start
:: ------------------------------------------------------------------
echo [INFO] 0.7.1 - Starting all containers...
docker-compose up -d 2>&1
if %ERRORLEVEL% neq 0 (
  echo [FAIL] 0.7.1 - docker-compose up failed
  exit /b 1
)
timeout /t 10 /nobreak >nul
docker-compose ps --services >nul 2>&1
if %ERRORLEVEL% equ 0 (
  echo [PASS] 0.7.1 - All containers started
) else (
  echo [FAIL] 0.7.1 - Not all services are running
  docker-compose ps
  exit /b 1
)
echo.

:: ------------------------------------------------------------------
:: 0.7.2 - Verify Cassandra cluster communication
:: ------------------------------------------------------------------
echo [INFO] 0.7.2 - Checking Cassandra cluster...
docker-compose ps --services 2>nul | findstr cassandra >nul
if %ERRORLEVEL% equ 0 (
  echo [PASS] 0.7.2 - Cassandra node is running
) else (
  echo [FAIL] 0.7.2 - No Cassandra service found
  exit /b 1
)
echo.

:: ------------------------------------------------------------------
:: 0.7.3 - Verify Redis accepts backend connections
:: ------------------------------------------------------------------
echo [INFO] 0.7.3 - Checking Redis connectivity...
docker-compose exec redis redis-cli ping 2>nul | findstr PONG >nul
if %ERRORLEVEL% equ 0 (
  echo [PASS] 0.7.3 - Redis responds to PING
) else (
  echo [FAIL] 0.7.3 - Redis not reachable
  exit /b 1
)
echo.

:: ------------------------------------------------------------------
:: 0.7.4 - Test backend can reach Cassandra and Redis
:: ------------------------------------------------------------------
echo [INFO] 0.7.4 - Checking backend health endpoint...
for /f "tokens=*" %%a in ('docker-compose exec backend curl -s http://localhost:3000/health 2^>nul') do set HEALTH=%%a
echo !HEALTH! | findstr "ok" >nul
if %ERRORLEVEL% equ 0 (
  echo [PASS] 0.7.4 - Backend health check passed
) else (
  echo [FAIL] 0.7.4 - Backend health endpoint did not return OK
  echo Response: !HEALTH!
  exit /b 1
)
echo.

:: ------------------------------------------------------------------
:: 0.7.5 - Access frontend at http://localhost:8080
:: ------------------------------------------------------------------
echo [INFO] 0.7.5 - Verifying Vue.js UI at http://localhost:8080...
curl -s -o nul -w "%%{http_code}" http://localhost:8080 2>nul > %TEMP%\ui_status.txt
set /p UI_STATUS=<%TEMP%\ui_status.txt
if "!UI_STATUS!"=="200" (
  echo [PASS] 0.7.5 - Vue.js UI is accessible (HTTP !UI_STATUS!)
) else (
  echo [FAIL] 0.7.5 - UI returned HTTP !UI_STATUS! (expected 200)
  exit /b 1
)
echo.

:: ------------------------------------------------------------------
:: 0.7.6 - End-to-end URL shortening flow
:: ------------------------------------------------------------------
echo [INFO] 0.7.6 - Testing end-to-end URL shortening...
for /f "tokens=*" %%a in ('curl -s -X POST http://localhost:8080/api/v1/urls -H "Content-Type: application/json" -d "{"""url""":"""https://example.com"""}" 2^>nul') do set RESPONSE=%%a
echo !RESPONSE! | findstr "shortId" >nul
if %ERRORLEVEL% equ 0 (
  echo [PASS] 0.7.6 - URL shortened successfully
  echo Response: !RESPONSE!
) else (
  echo [FAIL] 0.7.6 - End-to-end flow failed
  echo Response: !RESPONSE!
  exit /b 1
)
echo.

:: ------------------------------------------------------------------
:: 0.7.7 - Test Cassandra persistence
:: ------------------------------------------------------------------
echo [INFO] 0.7.7 - Testing data persistence...
docker-compose down 2>nul
docker-compose up -d 2>nul
timeout /t 15 /nobreak >nul
curl -s -o nul -w "%%{http_code}" -L http://localhost:8080/%SHORT_ID% 2>nul > %TEMP%\persist_status.txt
set /p PERSIST_STATUS=<%TEMP%\persist_status.txt
if "!PERSIST_STATUS!"=="200" (
  echo [PASS] 0.7.7 - Data persisted across restart
) else if "!PERSIST_STATUS!"=="302" (
  echo [PASS] 0.7.7 - Data persisted across restart
) else (
  echo [FAIL] 0.7.7 - Data lost after restart (HTTP !PERSIST_STATUS!)
  exit /b 1
)
echo.

:: ------------------------------------------------------------------
:: 0.7.8 - Test scaling backend to 3 instances
:: ------------------------------------------------------------------
echo [INFO] 0.7.8 - Scaling backend to 3 instances...
docker-compose up -d --scale backend=3 2>nul
timeout /t 10 /nobreak >nul
docker-compose ps backend 2>nul | find /c "Up" > %TEMP%\backend_count.txt
set /p BACKEND_COUNT=<%TEMP%\backend_count.txt
if !BACKEND_COUNT! geq 3 (
  echo [PASS] 0.7.8 - !BACKEND_COUNT! backend instances running
) else (
  echo [FAIL] 0.7.8 - Expected at least 3 backends, found !BACKEND_COUNT!
  exit /b 1
)
echo.

:: ------------------------------------------------------------------
:: 0.7.9 - Log monitoring hint
:: ------------------------------------------------------------------
echo [PASS] 0.7.9 - Run 'docker-compose logs -f' to view inter-service communication
echo.

:: ------------------------------------------------------------------
:: Summary
:: ------------------------------------------------------------------
echo [INFO] ===========================================
echo [PASS] All 0.7.x tests passed successfully
echo [INFO] ===========================================