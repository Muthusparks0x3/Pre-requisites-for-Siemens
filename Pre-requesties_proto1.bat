@echo off
setlocal

:MENU
cls
echo ##########  ##########  #########     ##########  #########  #########
echo ##       ## ##       ## ##            ##       ## ##         ##     ##
echo ##########  ##########  ######    ### ##########  ######     ##     ##
echo ##          ##      ##  ##            ##      ##  ##         ##    ###
echo ##          ##       ## #########     ##       ## #########  #########
echo                                                                      ##
echo.
echo ===========================================
echo   PCS 7 PRE-REQUISITES AND MANAGEMENT -- PROTOCAL-HELIX
echo ===========================================
echo.
echo Please select an option:
echo.
echo [1] Pre-requisites Analysis
echo [2] Pre-requisites for PCS 7 (Enable Features, Disable Protections)
echo [3] Full Revert Back
echo [4] Partial Revert Back
echo [5] Exit
echo.
set /p "choice=Enter your choice: "

if "%choice%"=="1" call :ANALYSIS MENU
if "%choice%"=="2" goto PRE_REQUISITES
if "%choice%"=="3" goto FULL_REVERT
if "%choice%"=="4" goto PARTIAL_REVERT
if "%choice%"=="5" exit
goto MENU

:ANALYSIS
set "mode=%~1"
cls
echo ==============================
echo   System Pre-Requisites Analysis
echo ==============================
echo.

:: --- Computer Name ---
echo Computer Name:
echo %COMPUTERNAME%
echo -----------------------------------------------

:: --- Keyboard Language ---
echo Keyboard Language:
powershell -ExecutionPolicy Bypass -Command "Get-WinUserLanguageList | ForEach-Object {$_.LanguageTag}"
echo -----------------------------------------------

:: --- Location / System Locale ---
echo Location / System Locale:
powershell -ExecutionPolicy Bypass -Command "Get-WinSystemLocale | Select-Object -ExpandProperty Name"
echo -----------------------------------------------

:: --- Display Resolution ---
echo Display Resolution:
for /f "tokens=2 delims==" %%a in ('wmic path Win32_VideoController get CurrentHorizontalResolution /value') do set xres=%%a
for /f "tokens=2 delims==" %%a in ('wmic path Win32_VideoController get CurrentVerticalResolution /value') do set yres=%%a
if defined xres if defined yres (echo %xres%x%yres%) else echo Unknown
echo -----------------------------------------------

:: --- Turn Off Display Timeout ---
for /f "tokens=5" %%a in ('powercfg /query SCHEME_CURRENT SUB_VIDEO VIDEOIDLE ^| findstr "Current AC Power Setting Index"') do set displayAC=%%a
for /f "tokens=5" %%a in ('powercfg /query SCHEME_CURRENT SUB_VIDEO VIDEOIDLE ^| findstr "Current DC Power Setting Index"') do set displayDC=%%a
set /a displayACm=%displayAC%/60
set /a displayDCm=%displayDC%/60
echo Display Off Timeout (AC/DC minutes): %displayACm% / %displayDCm%
echo -----------------------------------------------

:: --- Power Mode ---
echo Power Mode:
powercfg /GETACTIVESCHEME
echo -----------------------------------------------

:: --- Sleep Timeout ---
for /f "tokens=5" %%a in ('powercfg /query SCHEME_CURRENT SUB_SLEEP STANDBYIDLE ^| findstr "Current AC Power Setting Index"') do set sleepAC=%%a
for /f "tokens=5" %%a in ('powercfg /query SCHEME_CURRENT SUB_SLEEP STANDBYIDLE ^| findstr "Current DC Power Setting Index"') do set sleepDC=%%a
set /a sleepACm=%sleepAC%/60
set /a sleepDCm=%sleepDC%/60
echo Sleep Timeout (AC/DC minutes): %sleepACm% / %sleepDCm%
echo -----------------------------------------------

:: --- Firewall Status ---
echo Firewall Status:
for %%f in (Domain Private Public) do (
    for /f "tokens=2" %%a in ('netsh advfirewall show %%fprofile state ^| find "State"') do echo   %%f: %%a
)
echo -----------------------------------------------

:: --- Virus Protection (Defender) ---
echo Virus Protection (Defender):
powershell -ExecutionPolicy Bypass -Command "$s=Get-MpComputerStatus; Write-Output ('RealTimeProtection=' + $s.RealTimeProtectionEnabled + ', CloudProtection=' + $s.AMSIEnabled + ', Antivirus=' + $s.AntivirusEnabled)"
echo -----------------------------------------------

:: --- Windows Update Service ---
echo Windows Update Service:
for /f "tokens=3" %%a in ('sc query wuauserv ^| find "STATE"') do set wu=%%a
set wu=%wu: =%
if /i "%wu%"=="RUNNING" (echo ON) else (echo OFF)
echo -----------------------------------------------

:: --- Disk Defragment Schedule ---
echo Disk Defragment Schedule:
schtasks /Query /TN "Microsoft\Windows\Defrag\ScheduledDefrag" | findstr "Status"
echo ===============================================

:: --- Pause / Return ---
if /i "%mode%"=="MENU" (
    pause
    goto MENU
) else (
    exit /b
)

:PRE_REQUISITES
cls
echo ===========================================
echo     Executing PCS 7 Pre-requisites...
echo ===========================================
NET SESSION >NUL 2>&1
IF %ERRORLEVEL% NEQ 0 (
    echo ERROR: Please run this script as Administrator!
    pause
    goto MENU
)

:: ========================
:: 1. TURN OFF WINDOWS FIREWALL
:: ========================
echo.
echo [1/6] Turning Off Windows Firewall...
netsh advfirewall set allprofiles state off
if %errorlevel% equ 0 (echo [+] Firewall: Turned Off) else (echo [!] Failed to turn off Firewall)

:: ========================
:: 2. DISABLE WINDOWS DEFENDER FEATURES (Persistent)
:: ========================
echo.
echo [2/6] Disabling Windows Defender Features (Persistent)...
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection" /v "DisableRealtimeMonitoring" /t REG_DWORD /d 1 /f
if %errorlevel% equ 0 (echo [+] Real-time Protection: Disabled) else (echo [!] Failed to disable Real-time Protection)

reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows Defender\Spynet" /v "SpynetReporting" /t REG_DWORD /d 0 /f
if %errorlevel% equ 0 (echo [+] Cloud Protection: Disabled) else (echo [!] Failed to disable Cloud Protection)

reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows Defender\Spynet" /v "SubmitSamplesConsent" /t REG_DWORD /d 2 /f
if %errorlevel% equ 0 (echo [+] Sample Submission: Disabled) else (echo [!] Failed to disable Sample Submission)

powershell -Command "Set-MpPreference -DisableRealtimeMonitoring $true" >nul
powershell -Command "Set-MpPreference -MAPSReporting 0" >nul
powershell -Command "Set-MpPreference -SubmitSamplesConsent 2" >nul

:: ========================
:: 3. ENABLE MSMQ FEATURES
:: ========================
echo.
echo [3/6] Enabling MSMQ Features...
dism /online /enable-feature /featurename:MSMQ-Server /all /norestart /quiet
sc config MSMQ start= auto >nul
net start MSMQ >nul 2>&1
if %errorlevel% equ 0 (echo [+] MSMQ: Enabled and Running) else (echo [!] MSMQ already running or failed)

:: ========================
:: 4. ENABLE IIS FEATURES
:: ========================
echo.
echo [4/6] Enabling IIS Features...
dism /online /enable-feature /featurename:IIS-WebServerRole /all /norestart /quiet
dism /online /enable-feature /featurename:IIS-WebServer /all /norestart /quiet
dism /online /enable-feature /featurename:IIS-ASPNET45 /all /norestart /quiet
sc config W3SVC start= auto >nul
net start W3SVC >nul 2>&1
if %errorlevel% equ 0 (echo [+] IIS: Enabled and Running) else (echo [!] IIS already running or failed)

:: ========================
:: 5. GENERAL FEATURES
:: ========================
echo.
echo [5/6] Modifying General System Features...
powershell -command "Set-WinUserLanguageList -LanguageList en-US -Force"
powershell -command "Set-WinHomeLocation -GeoId 113"
powershell -command "(Get-CimInstance -Namespace root/WMI -ClassName WmiMonitorBrightnessMethods).WmiSetBrightness(1,100)" 2>nul
powercfg /change monitor-timeout-ac 0
powercfg /change monitor-timeout-dc 0
powercfg /change standby-timeout-ac 0
powercfg /change standby-timeout-dc 0
powercfg /setactive SCHEME_MIN
if %errorlevel% neq 0 powercfg /setactive SCHEME_MAX
reg add "HKEY_CURRENT_USER\Control Panel\Desktop" /v ScreenSaveActive /t REG_SZ /d "0" /f
sc stop wuauserv
sc config wuauserv start= disabled
schtasks /Change /TN "Microsoft\Windows\Defrag\ScheduledDefrag" /Disable 2>nul

:: ========================
:: 6. RERUN ANALYSIS
:: ========================
echo.
echo ======= [6/6] Re-running Pre-requisites Analysis =======
echo.
call :ANALYSIS PREREQ

:: ========================
:: 7. RESTART PROMPT
:: ========================
:RESTART_PROMPT_PRE
echo.
set /p "restart_choice=Do you want to perform a restart? [Y/N]: "
if /i "%restart_choice%"=="y" (
    echo Restarting now...
    shutdown /r /t 5
) else if /i "%restart_choice%"=="n" (
    echo Exiting without restart.
    goto MENU
) else (
    echo Invalid choice. Please enter Y or N.
    goto RESTART_PROMPT_PRE
)

:FULL_REVERT
cls
echo ===========================================
echo     Executing FULL Revert Back...
echo ===========================================
NET SESSION >NUL 2>&1
IF %ERRORLEVEL% NEQ 0 (
    echo ERROR: Please run this script as Administrator!
    pause
    goto MENU
)

:: ========================
:: 1. TURN ON WINDOWS FIREWALL
:: ========================
echo.
echo [1/3] Turning On Windows Firewall...
netsh advfirewall set allprofiles state on
if %errorlevel% equ 0 (echo [+] Firewall: Turned On) else (echo [!] Failed to turn on Firewall)

:: ========================
:: 2. RESTORE WINDOWS DEFENDER FEATURES
:: ========================
echo.
echo [2/3] Restoring Windows Defender Features...
reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection" /f >nul 2>&1
if %errorlevel% equ 0 (echo [+] Real-time Protection: Restored) else (echo [!] Could not delete Real-time Protection key)

reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows Defender\Spynet" /f >nul 2>&1
if %errorlevel% equ 0 (echo [+] Cloud Protection & Sample Submission: Restored) else (echo [!] Could not delete Spynet key)

:: ========================
:: 3. DISABLE MSMQ & IIS FEATURES
:: ========================
echo.
echo [3/3] Disabling MSMQ & IIS Features...
dism /online /disable-feature /featurename:MSMQ-Server /norestart /quiet
dism /online /disable-feature /featurename:IIS-WebServerRole /norestart /quiet

echo.
echo =================
echo - CREATED BY MLC
echo =================
echo.
echo All settings have been reverted.
echo A restart may be required for all changes to take effect.
echo.

:RESTART_PROMPT_FULL
set /p "restart_choice=Do you want to perform a restart? [Y/N]: "
if /i "%restart_choice%"=="y" (
    echo Restarting now...
    shutdown /r /t 5
) else if /i "%restart_choice%"=="n" (
    echo Exiting without restart.
) else (
    echo Invalid choice. Please enter Y or N.
    goto RESTART_PROMPT_FULL
)

pause
goto MENU

:PARTIAL_REVERT
cls
echo ===========================================
echo     Executing PARTIAL Revert Back...
echo ===========================================
NET SESSION >NUL 2>&1
IF %ERRORLEVEL% NEQ 0 (
    echo ERROR: Please run this script as Administrator!
    pause
    goto MENU
)

reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection" /f
reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows Defender\Spynet" /f
echo =================
echo CREATED BY MLC
echo =================
echo Protections will be restored after reboot.
pause
goto MENU

:EXIT_PROMPT
echo.
echo Exiting the script.
endlocal
exit /b