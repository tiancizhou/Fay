# Quality Guidelines

> Code quality standards for backend development.

---

## Overview

This repository is a Python 3.12 application with manual runtime/integration test scripts. No `pyproject.toml`, `setup.cfg`, `pytest.ini`, `.flake8`, `ruff.toml`, or `mypy.ini` files were found, and `requirements.txt` contains runtime dependencies only. Quality conventions therefore come from existing code patterns rather than enforced tooling.

The project favors pragmatic, direct modules, runtime fallbacks, and compatibility with Windows/macOS/Ubuntu as described in `README.md`.

---

## Required Patterns

### Keep imports compatible with root-level package execution

Many modules are executed directly and adjust `sys.path` to import root packages. Preserve this style for standalone servers/scripts under feature directories.

```python
# D:/Projects/GitHub/forks/Fay/mcp_servers/schedule_manager/web_server.py
project_root = _project_root()
if project_root not in sys.path:
    sys.path.insert(0, project_root)
```

```python
# D:/Projects/GitHub/forks/Fay/gui/flask_server.py
import os
import sys
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))
```

### Use small, focused helper functions for normalization/building payloads

Route modules often define local helpers for request normalization and response construction rather than adding classes prematurely.

```python
# D:/Projects/GitHub/forks/Fay/gui/flask_server.py
def _build_llm_url(base_url: str) -> str:
    if not base_url:
        return ""
    url = base_url.rstrip("/")
    if url.endswith("/chat/completions"):
        return url
    if url.endswith("/v1"):
        return url + "/chat/completions"
    return url + "/v1/chat/completions"
```

```python
# D:/Projects/GitHub/forks/Fay/gui/flask_server.py
def _prepare_llm_proxy_messages(messages):
    if isinstance(messages, str):
        return [{"role": "user", "content": messages}]
    if not isinstance(messages, list):
        return []
    ...
```

### Protect shared in-memory state with locks

Registry modules that hold process-global state use `threading.RLock`; DB classes use `threading.Lock` with a decorator.

```python
# D:/Projects/GitHub/forks/Fay/faymcp/tool_registry.py
_lock = threading.RLock()
_server_tools: Dict[int, Dict[str, ToolEntry]] = {}
_aggregated_cache: List[ToolEntry] = []

with _lock:
    server_map = _server_tools.setdefault(server_id, {})
    ...
    _rebuild_cache_locked()
```

```python
# D:/Projects/GitHub/forks/Fay/core/member_db.py
def synchronized(func):
  @functools.wraps(func)
  def wrapper(self, *args, **kwargs):
    with self.lock:
      return func(self, *args, **kwargs)
  return wrapper
```

### Preserve existing response shapes within a module

Do not mix response envelopes casually. Match the local route family's existing style.

```python
# D:/Projects/GitHub/forks/Fay/gui/flask_server.py
return jsonify({'result': 'error', 'message': '用户名和消息内容不能为空'})
```

```python
# D:/Projects/GitHub/forks/Fay/mcp_servers/schedule_manager/web_server.py
return jsonify({"success": False, "message": "标题和时间为必填项"})
```

---

## Forbidden / Avoid Patterns

Only avoid patterns clearly contradicted by the codebase:

- Do not introduce a new backend directory root such as `src/`; existing imports and scripts use root-level packages.
- Do not introduce an ORM or migration framework for isolated SQLite changes; observed persistence uses direct `sqlite3` and inline schema initialization.
- Do not add a new logging framework for core runtime code; use `utils.util.log` / `printInfo` in core/gui/faymcp modules, or the local `logger` in modules that already configure Python logging.
- Do not add new API response envelopes to existing route families; match the module's established JSON shape.
- Do not assume automated tests exist for a change. The `test/` directory mostly contains runnable manual scripts rather than pytest/unittest test cases.

---

## Testing Requirements

### Current test style is manual/integration-oriented

The `test/` directory contains scripts with `if __name__ == "__main__"` blocks, demo servers, WebSocket clients, and HTTP integration callers. There is no observed pytest suite.

Examples:

```python
# D:/Projects/GitHub/forks/Fay/test/test_fay_gpt_stream.py
if __name__ == "__main__":
    print("=" * 60)
    print("示例2：普通对话（不带观察数据）")
    print("=" * 60)
    test_gpt("你好", username="user", observation="")
```

```python
# D:/Projects/GitHub/forks/Fay/test/test_human_ws_api.py
if __name__ == "__main__":
    ws_url = f"ws://{config['url']}:10002"

    ws = websocket.WebSocketApp(ws_url,
                                on_open=on_open,
                                on_message=on_message,
                                on_error=on_error,
                                on_close=on_close)
```

### Basic verification commands

Repository setup from `README.md`:

```shell
pip install -r requirements.txt
python main.py start -config_center d19f7b0a-2b8a-4503-8c0d-1a587b90eb69
```

For code-only changes, at minimum run Python syntax compilation on touched modules when feasible:

```shell
python -m py_compile path/to/changed_file.py
```

For docs/spec-only changes, no runtime verification command is required beyond reviewing the modified Markdown.

### Windows startup script command contract

#### 1. Scope / Trigger

- Trigger: root-level Windows startup scripts are user-facing commands and deployment/platform behavior.
- Scope: `start_fay.bat` launches Fay through a repo-local virtual environment without changing Python application startup code.

#### 2. Signatures

```bat
start_fay.bat
python -m venv .venv
.venv\Scripts\python.exe -m pip install -r requirements.txt
.venv\Scripts\python.exe main.py start -config_center d19f7b0a-2b8a-4503-8c0d-1a587b90eb69
```

#### 3. Contracts

- Working directory: the script must switch to its own directory with `cd /d "%~dp0"` so double-click launch works.
- Virtual environment path: `.venv` at the repository root.
- Python command: use `python` only for venv creation; runtime launch uses `.venv\Scripts\python.exe`.
- Dependency install: run `.venv\Scripts\python.exe -m pip install -r requirements.txt` before every startup, including when `.venv` already exists, so stale/incomplete environments are synchronized.
- Runtime config: use the README quick-start `-config_center d19f7b0a-2b8a-4503-8c0d-1a587b90eb69` unless the startup requirement changes.

#### 4. Validation & Error Matrix

- `python -m venv .venv` fails -> print the failure context, `pause`, exit `1`.
- dependency installation fails -> print the failure context, `pause`, exit `1`.
- Fay startup exits with non-zero status -> print the failure context, `pause`, exit `1`.
- Fay stops normally with exit code `0` -> exit without pausing.

#### 5. Good/Base/Bad Cases

- Good: double-click `start_fay.bat` from Explorer; it switches to repo root, creates `.venv` if missing, installs dependencies, and launches Fay.
- Base: run `start_fay.bat` from `cmd` with existing `.venv`; it reuses `.venv\Scripts\python.exe`, synchronizes dependencies from `requirements.txt`, and launches Fay.
- Bad: use global `python main.py ...` from the batch script; this bypasses the project virtual environment and can load incompatible dependencies.

#### 6. Tests Required

- Review the batch file for `cd /d "%~dp0"`, `.venv\Scripts\python.exe`, and absence of `python3`.
- On Windows, run from repo root and verify the command reaches Fay startup.
- If testing a missing environment, temporarily move/remove `.venv` outside the repo, run the script, and verify dependency installation happens after venv creation.
- With an existing `.venv`, run the script and verify dependency installation still runs before Fay startup.
- Verify non-zero setup/startup failures pause before exiting so the error remains visible.

#### 7. Wrong vs Correct

Wrong:

```bat
python main.py start -config_center d19f7b0a-2b8a-4503-8c0d-1a587b90eb69
```

Correct:

```bat
cd /d "%~dp0"
if not exist ".venv\Scripts\python.exe" python -m venv ".venv"
".venv\Scripts\python.exe" -m pip install -r requirements.txt
".venv\Scripts\python.exe" main.py start -config_center d19f7b0a-2b8a-4503-8c0d-1a587b90eb69
```

---

## Impact Radius Checklist

Use this quick L1-L5 scan before changing code:

- L1 single function/module: verify local inputs, return values, fallback behavior, and syntax.
- L2 package/service: check callers inside the same package, shared globals, locks, and module-level state.
- L3 API/persistence boundary: verify JSON response shapes, SQLite schema/query compatibility, path/runtime assumptions, and data formats.
- L4 cross-service/runtime: check Fay core, Flask UI, MCP services, WebSocket clients, scheduler threads, and optional integrations that may consume the same data.
- L5 deployment/platform: check Windows/macOS/Ubuntu assumptions from `README.md`, PyInstaller/frozen paths, config files, and startup commands.

---

## Code Review Checklist

- Does the change fit the existing top-level package layout (`core/`, `gui/`, `faymcp/`, `mcp_servers/`, `utils/`)?
- Does it use the existing persistence pattern if touching SQLite: direct `sqlite3`, placeholders for values, explicit `commit()` and `close()`?
- Does it preserve the existing API response shape for the module being edited?
- Does it log through the module's established mechanism (`util.log`/`printInfo` or local `logger`)?
- Are optional integrations guarded with fallback behavior, as in existing LangSmith/MCP/dependency imports?
- If shared mutable state is introduced, is it protected with a lock as in `faymcp/tool_registry.py` or core DB wrappers?
- If the change adds a standalone script/server under a subdirectory, does it handle root imports and runtime paths like existing MCP server modules?
- What is the highest impacted layer in the L1-L5 impact radius checklist, and were callers/consumers at that layer checked?

---

## Known Gaps

- No enforced formatter/linter/type checker configuration was found.
- No automated pytest/unittest suite was found for the main backend. Existing tests are mostly manual integration scripts.
- There is no central error-handling or logging policy beyond observed module conventions.
