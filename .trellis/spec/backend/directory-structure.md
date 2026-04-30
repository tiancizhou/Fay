# Directory Structure

> How backend code is organized in this project.

---

## Overview

Fay is a Python application organized by runtime responsibility rather than a single `src/` package. Backend code lives at the repository root in top-level packages such as `core/`, `gui/`, `faymcp/`, `mcp_servers/`, `utils/`, `asr/`, `tts/`, `llm/`, and `scheduler/`.

There are no package-level convention docs beyond Trellis' managed `AGENTS.md` block, and no linter/typecheck configuration files were found. These guidelines describe patterns observed in the existing codebase.

---

## Directory Layout

```text
D:/Projects/GitHub/forks/Fay/
├── main.py                         # Main process entry point and CLI/bootstrap handling
├── fay_booter.py                   # Runtime startup/stop orchestration
├── core/                           # Core conversation, DB, audio/socket, and runtime services
│   ├── content_db.py               # SQLite conversation history repository
│   ├── member_db.py                # SQLite user profile repository
│   ├── fay_core.py                 # Core Fay interaction logic
│   ├── memory_service.py           # Memory-related service layer
│   └── wsa_server.py               # WebSocket server integration
├── gui/                            # Flask UI/API and desktop window code
│   ├── flask_server.py             # Main Flask API/UI server
│   └── window.py                   # Desktop UI window
├── faymcp/                         # Built-in MCP client/server/service integration
│   ├── mcp_service.py              # Flask UI/API for MCP server management
│   ├── mcp_client.py               # MCP client abstraction
│   ├── tool_registry.py            # In-memory MCP tool registry
│   └── resource_registry.py        # In-memory MCP resource registry with JSON persistence
├── mcp_servers/                    # Standalone MCP server implementations
│   └── schedule_manager/
│       ├── server.py               # Schedule manager MCP server and scheduler
│       └── web_server.py           # Schedule manager Flask API/UI
├── utils/                          # Shared helpers and third-party API adapters
│   ├── util.py                     # Logging, time, IP, and utility helpers
│   ├── config_util.py              # Config loading/saving globals
│   └── openai_api/                 # OpenAI-compatible API helpers/server
├── asr/, tts/, llm/                # Speech recognition, speech synthesis, and LLM integrations
├── scheduler/                      # Thread management helpers
└── test/                           # Manual integration scripts and demo servers
```

---

## Module Organization

### Entrypoints stay at the root or feature server directory

Root-level startup is handled by `main.py`, with runtime orchestration delegated to `fay_booter.py`. Standalone MCP servers use their own feature directories under `mcp_servers/`.

Observed examples:

```python
# D:/Projects/GitHub/forks/Fay/main.py
_preload_config_center(sys.argv[1:])
_maybe_run_mcp_stdio_runner(sys.argv[1:])

import time
import psutil
...
from gui import flask_server
```

```python
# D:/Projects/GitHub/forks/Fay/mcp_servers/schedule_manager/server.py
RUNTIME_DIR = _runtime_dir()
project_root = _project_root()
if project_root not in sys.path:
    sys.path.insert(0, project_root)
```

### Core business/runtime services go in `core/`

Conversation storage, user profiles, memory, WebSocket bridge, recorder, and core Fay behavior are kept in `core/`. These modules expose simple classes/functions and are imported directly by UI/API modules.

Observed examples:

```python
# D:/Projects/GitHub/forks/Fay/gui/flask_server.py
from core import wsa_server
from core import fay_core
from core import content_db
from core.interact import Interact
from core import member_db
```

```python
# D:/Projects/GitHub/forks/Fay/fay_booter.py
from core.interact import Interact
from core.recorder import Recorder
from core.wsa_server import MyServer
from core import wsa_server
from core import socket_bridge_service
```

### Flask route modules are service-specific

The main application HTTP API is in `gui/flask_server.py`. MCP management has a separate Flask app in `faymcp/mcp_service.py`. Standalone schedule management has `mcp_servers/schedule_manager/web_server.py`.

Observed examples:

```python
# D:/Projects/GitHub/forks/Fay/faymcp/mcp_service.py
app = Flask(__name__)
CORS(app, resources={r"/*": {"origins": "*"}})

@app.route('/api/mcp/servers', methods=['GET'])
def get_mcp_servers():
    return jsonify(mcp_servers)
```

```python
# D:/Projects/GitHub/forks/Fay/gui/flask_server.py
__app = Flask(__name__)
auth = HTTPBasicAuth()
CORS(__app, supports_credentials=True)

@__app.route('/api/send', methods=['post'])
def api_send():
    ...
```

### Shared helpers go in `utils/`

Cross-cutting helpers such as logging, time conversion, config loading, streaming helpers, and OpenAI-compatible API adapters live under `utils/`.

Observed examples:

```python
# D:/Projects/GitHub/forks/Fay/utils/util.py
LOGS_FILE_URL = "logs/log-" + time.strftime("%Y%m%d%H%M%S") + ".log"

def log(level, text):
    try:
        if not isinstance(text, str):
            text = str(text)
        printInfo(level, "系统", text)
    except Exception as e:
        print(f"记录系统日志时出错: {str(e)}")
```

---

## Naming Conventions

- Package and module names are lowercase with underscores when needed: `content_db.py`, `member_db.py`, `mcp_service.py`, `stream_manager.py`.
- Database wrapper classes use mixed/Pascal casing with historical underscores: `Content_Db`, `Member_Db`, `Authorize_Tb`.
- Flask endpoint functions often use `api_` prefixes for HTTP APIs: `api_submit`, `api_send`, `api_get_Msg` in `gui/flask_server.py`; `api_get_schedules`, `api_create_schedule` in `mcp_servers/schedule_manager/web_server.py`.
- Internal helper functions often use a single leading underscore or double-underscore for module-private helpers: `_runtime_dir`, `_project_root`, `_attach_prestart_metadata`, `__get_device_list`.
- Top-level constants are uppercase: `DB_PATH`, `RUNTIME_DIR`, `MCP_DATA_FILE`, `CONNECTION_CHECK_INTERVAL`.

---

## Examples of Well-Matched Organization

- `D:/Projects/GitHub/forks/Fay/core/content_db.py` - focused SQLite repository for conversation history; exposes `new_instance()` singleton and synchronized methods.
- `D:/Projects/GitHub/forks/Fay/faymcp/tool_registry.py` - focused in-memory registry using module-level state protected by `threading.RLock` and typed helper functions.
- `D:/Projects/GitHub/forks/Fay/mcp_servers/schedule_manager/server.py` plus `web_server.py` - standalone feature directory containing MCP logic and its companion Web API.

---

## Avoid Patterns Supported by the Codebase

- Do not create a separate `src/` tree for backend additions; existing imports assume root-level packages.
- Do not place service-specific MCP server code in `core/`; standalone MCP servers are under `mcp_servers/<server_name>/`.
- Do not put shared utilities inside route modules when they are reused across services; use `utils/` or a feature registry module such as `faymcp/tool_registry.py`.
