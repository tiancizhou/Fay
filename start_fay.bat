@echo off
setlocal

cd /d "%~dp0"

set "VENV_DIR=.venv"
set "PYTHON_EXE=%VENV_DIR%\Scripts\python.exe"

if not exist "%PYTHON_EXE%" (
    echo Creating Python virtual environment in %VENV_DIR%...
    python -m venv "%VENV_DIR%"
    if errorlevel 1 (
        set "FAIL_MESSAGE=Failed to create Python virtual environment."
        goto fail
    )
)

echo Installing dependencies from requirements.txt...
"%PYTHON_EXE%" -m pip install -r requirements.txt
if errorlevel 1 (
    set "FAIL_MESSAGE=Failed to install dependencies from requirements.txt."
    goto fail
)

echo Starting Fay...
"%PYTHON_EXE%" main.py start -config_center d19f7b0a-2b8a-4503-8c0d-1a587b90eb69
if errorlevel 1 (
    set "FAIL_MESSAGE=Fay startup failed."
    goto fail
)

exit /b 0

:fail
echo.
echo %FAIL_MESSAGE% See the error above.
pause
exit /b 1
