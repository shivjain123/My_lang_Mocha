@echo off
setlocal enabledelayedexpansion

set MOCHA_DIR=%~dp0
set COMPILER=%MOCHA_DIR%mocha_compile.py
set REPL=%MOCHA_DIR%mocha_repl.py
set DOC=%MOCHA_DIR%mocha_doc.py

if "%1"=="" goto :show_help_noargs
if "%1"=="help" goto :show_help
if "%1"=="--help" goto :show_help
if "%1"=="-h" goto :show_help
goto :after_help

:show_help_noargs
call :print_help
exit /b 1

:show_help
call :print_help
exit /b 0

:print_help
echo Mocha Compiler CLI
echo.
echo Usage:
echo   mocha ^<file.mch^>                 Compile a file
echo   mocha ^<file.mch^> --debug         Compile with debug output
echo   mocha execute ^<file.mch^>         Compile and run immediately
echo   mocha --lib ^<libfile.mch^>        Compile a library
echo   mocha doc ^<file.mch^>             Generate documentation
echo   mocha repl                       Launch interactive REPL
echo   mocha wasm ^<file.mch^> [fn ...]   Build a WebAssembly module
echo   mocha help                       Show this message
echo   mocha serve [page.html] [port]   Open a wasm page in the browser
echo   mocha web ^<file.mch^> [fn ...]    Build as WebAssembly and open it in the browser
echo   mocha update                     Pull the latest compiler + libraries
exit /b

:after_help

if "%1"=="update" (
    python "%MOCHA_DIR%mocha_update.py" update
    exit /b
)

python "%MOCHA_DIR%mocha_update.py" check

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

if "%1"=="wasm" (
    if "%2"=="" (
        echo Usage: mocha wasm ^<file.mch^> [function ...]
        exit /b 1
    )
    python "%COMPILER%" --wasm "%~f2" "%~dpn2" %3 %4 %5 %6 %7 %8 %9
    exit /b
)

if "%1"=="serve" (
    if "%2"=="" (
        python "%MOCHA_DIR%mocha_serve.py"
    ) else (
        python "%MOCHA_DIR%mocha_serve.py" "%~f2" %3
    )
    exit /b
)

if "%1"=="web" (
    if "%2"=="" (
        echo Usage: mocha web ^<file.mch^> [function ...]
        exit /b 1
    )
    python "%COMPILER%" --wasm "%~f2" "%~dpn2" %3 %4 %5 %6 %7 %8 %9
    if !errorlevel!==0 python "%MOCHA_DIR%mocha_serve.py" "%~dpn2.html"
    exit /b !errorlevel!
)

if /i not "%~x1"==".mch" (
    echo Unknown command '%1'. Run 'mocha help' to see available commands.
    exit /b 1
)

set INPUT=%~f1

set INPUT=%~f1
set OUTPUT=%~dpn1
set EXTRA_FLAGS=

if "%2"=="--debug" set EXTRA_FLAGS=--debug
if "%3"=="--debug" set EXTRA_FLAGS=--debug

python "%COMPILER%" "%INPUT%" "%OUTPUT%" %EXTRA_FLAGS%