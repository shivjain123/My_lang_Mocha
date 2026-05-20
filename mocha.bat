@echo off
if "%1"=="" (
    echo Usage: mocha ^<file.mch^>
    exit /b 1
)

if "%1"=="--lib" (
    python "C:\Users\shiv jain\Coding_Projects\My_Codes\Mocha\Python_AND_ExecutableFiles\mocha_compile.py" --lib "%~f2"
    exit /b
)

set INPUT=%~f1
set OUTPUT=%~dpn1
set EXTRA_FLAGS=

if "%2"=="--debug" set EXTRA_FLAGS=--debug
if "%3"=="--debug" set EXTRA_FLAGS=--debug

python "C:\Users\shiv jain\Coding_Projects\My_Codes\Mocha\Python_AND_ExecutableFiles\mocha_compile.py" "%INPUT%" "%OUTPUT%" %EXTRA_FLAGS%