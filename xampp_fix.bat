@echo off
title XAMPP MySQL Auto-Fix
color 0A
setlocal EnableDelayedExpansion

set XAMPP=C:\xampp
set DATA=%XAMPP%\mysql\data
set BIN=%XAMPP%\mysql\bin
set MYSQL_DB=%DATA%\mysql
set FIXED=0

echo ============================================
echo   XAMPP MySQL Auto-Fix by ke1thdev
echo   github.com/ke1thdev
echo ============================================
echo.

:: ── Admin check ──────────────────────────────
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo [!] Relaunching as Administrator...
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

:: ── Step 1: Kill stale processes ─────────────
echo [1] Stopping stale MySQL processes...
taskkill /f /im mysqld.exe >nul 2>&1
net stop mysql >nul 2>&1
timeout /t 2 /nobreak >nul
echo     Done.
echo.

:: ── Step 2: Delete stale PID ──────────────────
echo [2] Checking for stale PID file...
if exist "%DATA%\mysql.pid" (
    del /f /q "%DATA%\mysql.pid"
    echo     [FIXED] Deleted stale mysql.pid
    set FIXED=1
) else (
    echo     No PID file found.
)
echo.

:: ── Step 3: Port 3306 conflict ────────────────
echo [3] Checking if port 3306 is in use...
set PORT_PID=
for /f "tokens=5" %%a in ('netstat -ano ^| findstr ":3306 "') do set PORT_PID=%%a
if defined PORT_PID (
    echo     [!] Port 3306 is held by PID !PORT_PID!
    echo     Killing conflicting process...
    taskkill /f /pid !PORT_PID! >nul 2>&1
    echo     [FIXED] Killed PID !PORT_PID!
    set FIXED=1
) else (
    echo     Port 3306 is free.
)
echo.

:: ── Step 4: Disk space check ──────────────────
echo [4] Checking disk space...
set FREE_BYTES=0
for /f "tokens=3" %%a in ('dir "%DATA%" /-c ^| findstr /i "bytes free"') do set FREE_BYTES=%%a
set /a FREE_MB=!FREE_BYTES! / 1048576 2>nul
echo     Free space: ~!FREE_MB! MB
if !FREE_MB! LSS 500 (
    echo     [WARNING] Less than 500MB free - MySQL may fail to write temp files!
    echo     Free up disk space and try again.
) else (
    echo     Disk space OK.
)
echo.

:: ── Step 5: InnoDB redo log corruption ───────
echo [5] Removing stale InnoDB redo log files...
set INNODB_FIXED=0
if exist "%DATA%\ib_logfile0" (
    del /f /q "%DATA%\ib_logfile0"
    set INNODB_FIXED=1
)
if exist "%DATA%\ib_logfile1" (
    del /f /q "%DATA%\ib_logfile1"
    set INNODB_FIXED=1
)
if !INNODB_FIXED! equ 1 (
    echo     [FIXED] Removed stale InnoDB redo logs - will be recreated on start
    set FIXED=1
) else (
    echo     No stale InnoDB log files found.
)
echo.

:: ── Step 6: Aria system table repair ─────────
echo [6] Checking Aria system tables (.MAI/.MAD)...
set ARIA_COUNT=0
for %%T in (db global_priv user tables_priv columns_priv procs_priv proxies_priv roles_mapping servers func plugin proc event time_zone time_zone_name help_topic help_category help_keyword) do (
    if exist "%MYSQL_DB%\%%T.MAI" (
        "%BIN%\aria_chk.exe" --check --silent "%MYSQL_DB%\%%T" >nul 2>&1
        if !errorlevel! neq 0 (
            echo     Repairing Aria table: %%T
            "%BIN%\aria_chk.exe" --recover --force --silent "%MYSQL_DB%\%%T" >nul 2>&1
            set /a ARIA_COUNT+=1
            set FIXED=1
        )
    )
)
if !ARIA_COUNT! equ 0 (
    echo     All Aria tables OK.
) else (
    echo     [FIXED] Repaired !ARIA_COUNT! Aria table(s).
)
echo.

:: ── Step 7: MyISAM system table repair ───────
echo [7] Checking MyISAM system tables (.MYI/.MYD)...
set MYISAM_COUNT=0
for %%T in (db user tables_priv columns_priv procs_priv proxies_priv func plugin proc event servers) do (
    if exist "%MYSQL_DB%\%%T.MYI" (
        "%BIN%\myisamchk.exe" --check --silent "%MYSQL_DB%\%%T.MYI" >nul 2>&1
        if !errorlevel! neq 0 (
            echo     Repairing MyISAM table: %%T
            "%BIN%\myisamchk.exe" --recover --force --silent "%MYSQL_DB%\%%T.MYI" >nul 2>&1
            set /a MYISAM_COUNT+=1
            set FIXED=1
        )
    )
)
if !MYISAM_COUNT! equ 0 (
    echo     All MyISAM tables OK.
) else (
    echo     [FIXED] Repaired !MYISAM_COUNT! MyISAM table(s).
)
echo.

:: ── Step 8: Temp file cleanup ─────────────────
echo [8] Cleaning up temp and lock files...
set TEMP_COUNT=0
if exist "%DATA%\ibtmp1" (
    del /f /q "%DATA%\ibtmp1" >nul 2>&1
    set /a TEMP_COUNT+=1
)
for %%F in ("%DATA%\*.lock") do (
    del /f /q "%%F" >nul 2>&1
    set /a TEMP_COUNT+=1
)
if !TEMP_COUNT! gtr 0 (
    echo     [FIXED] Removed !TEMP_COUNT! temp/lock file(s).
    set FIXED=1
) else (
    echo     No temp files to clean.
)
echo.

:: ── Step 9: Attempt MySQL start ───────────────
echo [9] Starting MySQL...
if exist "%XAMPP%\xampp_start.exe" (
    start "" "%XAMPP%\xampp_start.exe"
) else (
    net start mysql >nul 2>&1
)
timeout /t 4 /nobreak >nul

:: ── Step 10: Verify ───────────────────────────
tasklist /fi "imagename eq mysqld.exe" 2>nul | find /i "mysqld.exe" >nul
if %errorlevel% equ 0 (
    echo     [OK] mysqld.exe is running!
    echo.
    echo ============================================
    echo   SUCCESS - MySQL is up
    echo   http://localhost/phpmyadmin
    echo ============================================
) else (
    echo     [FAILED] MySQL still not running.
    echo.
    echo ============================================
    echo   MANUAL DEBUG NEEDED
    echo   Run this in CMD and paste the output:
    echo   "%BIN%\mysqld.exe" --console
    echo ============================================
    echo.
    echo   Issues NOT covered by this script:
    echo   - ibdata1 or .ibd file corruption
    echo     (restore from backup or use innodb_force_recovery)
    echo   - my.ini misconfiguration
    echo     (check C:\xampp\mysql\data\my.ini)
    echo   - Windows Defender quarantined a data file
    echo     (Windows Security - Protection History - Restore)
    echo ============================================
)

echo.
echo ── Summary ──────────────────────────────────
if !FIXED! equ 1 (
    echo   One or more fixes were applied.
) else (
    echo   No common issues detected automatically.
    echo   Run mysqld --console for deeper diagnosis.
)
echo ─────────────────────────────────────────────
echo.
pause
