@echo off
setlocal enabledelayedexpansion

set MOCHA_DIR=%~dp0
set COMPILER=%MOCHA_DIR%mocha_compile.py
set REPL=%MOCHA_DIR%mocha_repl.py
set DOC=%MOCHA_DIR%mocha_doc.py

if "%1"=="" (
    echo Usage: mocha ^<file.mch^>
    echo        mocha --lib ^<libfile.mch^>
    echo        mocha repl
    exit /b 1
)

if "%1"=="repl" (
    python "%REPL%"
    exit /b
)

if "%1"=="doc" (
    python "%DOC%" "%~f2"
    exit /b
)

if "%1"=="execute" (
    python "%COMPILER%" "%~f2" "%CD%\%~n2"
    if !errorlevel!==0 (
        "%CD%\%~n2.exe"
        set EXECEXIT=!errorlevel!
        echo.
        if !EXECEXIT!==0 (
            echo ✅ Execution Done.
        ) else (
            echo ❌ Execution failed ^(exit code !EXECEXIT!^)
        )
        exit /b !EXECEXIT!
    )
    exit /b !errorlevel!
)

if "%1"=="--lib" (
    python "%COMPILER%" --lib "%~f2"
    exit /b
)

set INPUT=%~f1
set OUTPUT=%~dpn1
set EXTRA_FLAGS=

if "%2"=="--debug" set EXTRA_FLAGS=--debug
if "%3"=="--debug" set EXTRA_FLAGS=--debug

python "%COMPILER%" "%INPUT%" "%OUTPUT%" %EXTRA_FLAGS%