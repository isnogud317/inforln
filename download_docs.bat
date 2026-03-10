@echo off
setlocal EnableDelayedExpansion

:: ============================================================
::  download_docs.bat  -  Batch download Infor LN documentation
::
::  Usage:
::    download_docs.bat [url_list.txt] [output_folder]
::
::  Defaults:
::    url_list.txt  = urls.txt  (one URL per line)
::    output_folder = downloads
::
::  Lines starting with # and blank lines are skipped.
::  Requires curl (built-in on Windows 10 1803+ / Server 2019+).
:: ============================================================

:: --- Arguments ---
set "URL_FILE=%~1"
set "OUT_DIR=%~2"

if "%URL_FILE%"=="" set "URL_FILE=urls.txt"
if "%OUT_DIR%"==""  set "OUT_DIR=downloads"

:: --- Validate input file ---
if not exist "%URL_FILE%" (
    echo [ERROR] URL list file not found: %URL_FILE%
    echo.
    echo Usage: %~nx0 [url_list.txt] [output_folder]
    exit /b 1
)

:: --- Verify curl is available ---
where curl >nul 2>&1
if errorlevel 1 (
    echo [ERROR] curl not found. Please install curl or use Windows 10 1803+.
    exit /b 1
)

:: --- Create output directory ---
if not exist "%OUT_DIR%" (
    mkdir "%OUT_DIR%"
    echo [INFO] Created output folder: %OUT_DIR%
)

echo.
echo ============================================================
echo  Infor LN Documentation Downloader
echo  URL list : %URL_FILE%
echo  Output   : %OUT_DIR%
echo ============================================================
echo.

set /a TOTAL=0
set /a OK=0
set /a FAIL=0
set /a SKIP=0

:: --- Process each line ---
for /f "usebackq tokens=* delims=" %%L in ("%URL_FILE%") do (
    set "LINE=%%L"

    :: Trim leading spaces/tabs (basic)
    for /f "tokens=* delims= " %%T in ("!LINE!") do set "LINE=%%T"

    :: Skip blank lines
    if "!LINE!"=="" (
        set /a SKIP+=1
        goto :continue
    )

    :: Skip comment lines starting with #
    set "FIRST_CHAR=!LINE:~0,1!"
    if "!FIRST_CHAR!"=="#" (
        set /a SKIP+=1
        goto :continue
    )

    set /a TOTAL+=1
    set "URL=!LINE!"

    :: Derive a filename from the URL (last path segment, strip query string)
    for %%U in ("!URL!") do set "FILENAME=%%~nxU"

    :: Remove query string if present (everything from ? onward)
    for /f "delims=?" %%Q in ("!FILENAME!") do set "FILENAME=%%Q"

    :: Fallback filename when URL has no useful last segment
    if "!FILENAME!"=="" set "FILENAME=doc_!TOTAL!.html"

    :: Avoid overwriting - append counter if file already exists
    set "DEST=%OUT_DIR%\!FILENAME!"
    if exist "!DEST!" (
        set "BASE=!FILENAME!"
        for %%E in ("!FILENAME!") do (
            set "BASE=%%~nE"
            set "EXT=%%~xE"
        )
        set "DEST=%OUT_DIR%\!BASE!_!TOTAL!!EXT!"
    )

    echo [!TOTAL!] Downloading: !URL!
    echo      -> !DEST!

    curl --silent --show-error --location --retry 3 --retry-delay 2 ^
         --connect-timeout 30 --max-time 120 ^
         --output "!DEST!" "!URL!"

    if errorlevel 1 (
        echo      [FAILED]
        set /a FAIL+=1
        :: Remove partial file on failure
        if exist "!DEST!" del /q "!DEST!"
    ) else (
        echo      [OK]
        set /a OK+=1
    )
    echo.

    :continue
)

echo ============================================================
echo  Done.
echo  Downloaded : !OK!
echo  Failed     : !FAIL!
echo  Skipped    : !SKIP! (blank/comment lines)
echo ============================================================

if !FAIL! gtr 0 exit /b 1
exit /b 0
