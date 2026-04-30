# Use uv for Windows Startup Virtual Environment

## Goal

Update the Windows startup script so Fay starts through a `uv`-managed project-local virtual environment instead of using `python -m venv` and direct pip.

## What I Already Know

* The user wants Python startup to use a uv virtual environment.
* Existing `start_fay.bat` is a root-level Windows startup script.
* The script must keep double-click support by switching to its own directory.
* The script should keep failure pauses so users can read setup/startup errors.
* `requirements.txt` is the current dependency source.
* Runtime files changed by the app are present in the working tree and should not be modified by this task.

## Requirements

* Update root-level `start_fay.bat` to use `uv` for virtual environment creation and dependency synchronization.
* Use `.venv` at the repository root as the virtual environment directory.
* Create `.venv` with `uv venv .venv` if `.venv\Scripts\python.exe` is missing.
* Synchronize dependencies before startup using `uv pip install --python .venv\Scripts\python.exe -r requirements.txt`.
* Launch Fay with `.venv\Scripts\python.exe main.py start -config_center d19f7b0a-2b8a-4503-8c0d-1a587b90eb69`.
* Fail clearly and pause if `uv` is not installed, venv creation fails, dependency sync fails, or Fay startup exits non-zero.
* Exit cleanly without pausing when Fay stops normally.
* Do not modify Python application code or runtime config files.

## Acceptance Criteria

* [x] Running `start_fay.bat` creates `.venv` with `uv venv .venv` when missing.
* [x] Running `start_fay.bat` with existing `.venv` reuses `.venv\Scripts\python.exe`.
* [x] Every run synchronizes `requirements.txt` with `uv pip install --python .venv\Scripts\python.exe -r requirements.txt` before Fay startup.
* [x] The script launches Fay through `.venv\Scripts\python.exe` with the README quick-start config center argument.
* [x] The script works when double-clicked by switching to its own directory.
* [x] The script pauses on setup/startup failure and does not pause on normal shutdown.
* [x] The script does not use `python -m venv` or `.venv\Scripts\python.exe -m pip install` for environment management.

## Definition of Done

* `start_fay.bat` updated.
* Backend quality guideline command contract updated to describe uv-managed startup.
* Trellis check runs before completion.

## Out of Scope

* Installing `uv` automatically.
* Adding `pyproject.toml`, lockfiles, or changing dependency declaration format.
* Changing Python application startup code.
* Editing runtime files such as `memory/fay.db`, `faymcp/data/mcp_servers.json`, or `cache_data/config.json`.

## Technical Notes

* Current Windows command should use `uv`, not `python -m venv`.
* Current dependency source remains `requirements.txt`.
* Existing startup command target remains `main.py start -config_center d19f7b0a-2b8a-4503-8c0d-1a587b90eb69`.
