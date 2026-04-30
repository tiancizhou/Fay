# Add Windows Startup BAT Script

## Goal

Add a Windows-friendly batch script that starts Fay with the README's quick-start command so users can launch the project without typing the full command each time.

## Requirements

* Add a root-level `.bat` startup script.
* Use `python`, not `python3`, for Windows compatibility.
* Start the project through a project-local Python virtual environment.
* Use `.venv` at the repository root as the virtual environment directory.
* Create `.venv` with `python -m venv .venv` if it does not exist.
* Install/synchronize dependencies from `requirements.txt` before every startup, including when `.venv` already exists.
* Start the project with `.venv\Scripts\python.exe main.py start -config_center d19f7b0a-2b8a-4503-8c0d-1a587b90eb69`.
* Keep the script simple and easy to double-click or run from `cmd`.
* Pause on failure so users can read the error.

## Acceptance Criteria

* [x] Running the script from the repo root creates `.venv` if missing, installs/synchronizes `requirements.txt`, and starts Fay using the README quick-start command.
* [x] Running the script when `.venv` already exists reuses `.venv\Scripts\python.exe` and still installs/synchronizes `requirements.txt` before startup.
* [x] The script works when double-clicked by first switching to its own directory.
* [x] The script uses `python`, not `python3`, for venv creation.
* [x] The script exits cleanly after Fay stops, and pauses on setup/startup failure.

## Definition of Done

* Script added at repository root.
* Script behavior reviewed for Windows compatibility.
* Trellis check runs before completion.

## Out of Scope

* Changing Python application startup code.
* Editing runtime configuration files such as `system.conf`.

## Technical Notes

* README quick start: `python main.py start -config_center d19f7b0a-2b8a-4503-8c0d-1a587b90eb69`.
* Current project environment is Windows; use `python` rather than `python3`.
