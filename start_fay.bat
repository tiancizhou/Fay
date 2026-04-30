@echo off
setlocal

cd /d "%~dp0"

set "VENV_DIR=.venv"
set "PYTHON_EXE=%VENV_DIR%\Scripts\python.exe"

where uv >nul 2>nul
if errorlevel 1 (
    set "FAIL_MESSAGE=uv is not installed or is not available on PATH. Install uv, then run this script again."
    goto fail
)

if not exist "%PYTHON_EXE%" (
    echo Creating uv virtual environment in %VENV_DIR%...
    uv venv "%VENV_DIR%"
    if errorlevel 1 (
        set "FAIL_MESSAGE=Failed to create uv virtual environment."
        goto fail
    )
)

echo Synchronizing dependencies from requirements.txt...
uv pip install --python "%PYTHON_EXE%" -r requirements.txt
if errorlevel 1 (
    set "FAIL_MESSAGE=Failed to synchronize dependencies from requirements.txt."
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
