@echo off
title XAMPP MySQL Auto-Fix
color 0A
setlocal

set XAMPP=C:\xampp
set DATA=%XAMPP%\mysql\data
set BIN=%XAMPP%\mysql\bin
set MYSQL_DB=%DATA%\mysql

echo ============================================
echo   XAMPP MySQL Auto-Fix by ke1thdev
echo ============================================
echo.

:: Must run as admin
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo [!] Not running as Administrator. Relaunching...
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

:: Step 1 - Stop XAMPP MySQL service and kill any stale mysqld
echo [1/6] Stopping any running MySQL processes...
taskkill /f /im mysqld.exe >nul 2>&1
net stop mysql >nul 2>&1
timeout /t 2 /nobreak >nul
echo     Done.

:: Step 2 - Delete stale PID file
echo [2/6] Removing stale PID file...
if exist "%DATA%\mysql.pid" (
    del /f /q "%DATA%\mysql.pid"
    echo     Deleted mysql.pid
) else (
    echo     No PID file found, skipping.
)

:: Step 3 - Delete InnoDB log files (fixes log corruption)
echo [3/6] Removing InnoDB redo log files...
if exist "%DATA%\ib_logfile0" del /f /q "%DATA%\ib_logfile0" && echo     Deleted ib_logfile0
if exist "%DATA%\ib_logfile1" del /f /q "%DATA%\ib_logfile1" && echo     Deleted ib_logfile1

:: Step 4 - Repair Aria system tables
echo [4/6] Repairing Aria system tables...
for %%T in (db global_priv user tables_priv columns_priv procs_priv proxies_priv roles_mapping servers func plugin proc event) do (
    if exist "%MYSQL_DB%\%%T.MAI" (
        "%BIN%\aria_chk.exe" --recover --force --silent "%MYSQL_DB%\%%T" >nul 2>&1
        echo     Repaired: %%T
    )
)

:: Step 5 - Check disk space
echo [5/6] Checking disk space...
for /f "tokens=3" %%a in ('dir "%DATA%" /-c ^| findstr /i "bytes free"') do set FREE=%%a
echo     Free space on data drive: %FREE% bytes

:: Step 6 - Start MySQL via XAMPP
echo [6/6] Starting MySQL...
if exist "%XAMPP%\xampp_start.exe" (
    start "" "%XAMPP%\xampp_start.exe"
) else (
    net start mysql >nul 2>&1
)

timeout /t 3 /nobreak >nul

:: Verify MySQL is up
tasklist /fi "imagename eq mysqld.exe" 2>nul | find /i "mysqld.exe" >nul
if %errorlevel% equ 0 (
    echo.
    echo ============================================
    echo   [OK] MySQL is running!
    echo   Open: http://localhost/phpmyadmin
    echo ============================================
) else (
    echo.
    echo ============================================
    echo   [!!] MySQL still not running.
    echo   Run mysqld --console for more details:
    echo   "%BIN%\mysqld.exe" --console
    echo ============================================
)

echo.
pause
