# Logging Guidelines

> How logging is done in this project.

---

## Overview

The main project logging helper is `utils.util.log(level, text)` / `utils.util.printInfo(level, sender, text, send_time=-1)`. It prints formatted logs to stdout, sends higher-level logs to connected WebSocket clients, and writes level `>= 3` logs asynchronously to `logs/log-<timestamp>.log`.

Some standalone modules use Python's `logging` module, especially standalone MCP servers. Flask's default/Werkzeug request logging is disabled in the main UI server.

---

## Log Levels

The custom `util.log` level is numeric. The codebase does not define named constants, but observed behavior is:

- `level >= 3`: `utils.util.printInfo` sends messages to WebSocket clients and writes to a log file.
- `level 1`: commonly used for normal system status messages and errors in many modules.
- `level 2`: used for warning-like optional integration failures such as LangSmith tracing.

Implementation:

```python
# D:/Projects/GitHub/forks/Fay/utils/util.py
def printInfo(level, sender, text, send_time=-1):
    ...
    logStr = '[{}][{}] {}'.format(format_time, sender, text)
    print(logStr)

    if level >= 3:
        if wsa_server.get_web_instance().is_connected(sender):
            wsa_server.get_web_instance().add_cmd({"panelMsg": text} if sender == "系统" else {"panelMsg": text, "Username" : sender})
        ...
        MyThread(target=__write_to_file, args=[logStr]).start()
```

Examples:

```python
# D:/Projects/GitHub/forks/Fay/main.py
util.log(1, '程序退出，正在清理资源...')
util.log(1, f'停止线程时出错: {e}')
```

```python
# D:/Projects/GitHub/forks/Fay/gui/flask_server.py
except Exception as exc:
    util.log(2, f"LangSmith proxy tracing init failed: {exc}")
    return None
```

```python
# D:/Projects/GitHub/forks/Fay/fay_booter.py
util.printInfo(3, "语音", '{}'.format(interact.data["msg"]), time.time())
```

---

## Structured Logging and Format

Custom logs are plain text, not JSON. Format is:

```text
[YYYY-MM-DD HH:MM:SS.d][sender] message
```

The timestamp includes tenths of a second in `printInfo`, and log files are named by process start time.

```python
# D:/Projects/GitHub/forks/Fay/utils/util.py
LOGS_FILE_URL = "logs/log-" + time.strftime("%Y%m%d%H%M%S") + ".log"
format_time = time.strftime('%Y-%m-%d %H:%M:%S', time.localtime(send_time)) + f".{int(send_time % 1 * 10)}"
logStr = '[{}][{}] {}'.format(format_time, sender, text)
```

Standalone MCP server logs use Python logging's default configured format:

```python
# D:/Projects/GitHub/forks/Fay/mcp_servers/schedule_manager/server.py
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(name)s - %(levelname)s - %(message)s')
logger = logging.getLogger("schedule_manager")
```

---

## What to Log

### Lifecycle and cleanup events

```python
# D:/Projects/GitHub/forks/Fay/main.py
util.log(1, '正在停止所有线程...')
stopAll()
util.log(1, '所有线程已停止')
```

### External service connection status

```python
# D:/Projects/GitHub/forks/Fay/faymcp/mcp_service.py
util.log(1, f"正在连接MCP服务器: {server['name']} ({server.get('ip', '')})")
...
util.log(1, f"MCP服务器连接成功: {updated_server['name']}，获取到 {len(tools_list)} 个工具")
```

### Database/service operation failures

```python
# D:/Projects/GitHub/forks/Fay/core/content_db.py
except Exception as e:
    util.log(1, f"删除用户消息失败: {e}")
    deleted_count = 0
```

### User-facing interaction events

```python
# D:/Projects/GitHub/forks/Fay/gui/flask_server.py
util.printInfo(1, username, '[文字发送按钮]{}'.format(interact.data["msg"]), time.time())
```

### Standalone feature server events

```python
# D:/Projects/GitHub/forks/Fay/mcp_servers/schedule_manager/server.py
logger.info(f"添加日程成功: {title} - {schedule_time} (重复规则: {repeat_rule})")
logger.error(f"添加日程失败: {e}")
```

---

## What NOT to Log

No explicit repository policy was found for secrets or PII. Based on observed code, avoid adding new logs that expose credentials or tokens:

- MCP server configs include `key` and `env` fields in `faymcp/mcp_service.py`; do not log full server config objects.
- HTTP test scripts include `Authorization` headers in `test/test_fay_gpt_stream.py`; do not copy those values into runtime logs.
- User messages are already logged in interaction paths, so be careful when adding additional logs around full prompts, observations, or memory contents.

Supported example of avoiding excessive logs: old MCP disconnect logging is commented out rather than emitting noisy connection details.

```python
# D:/Projects/GitHub/forks/Fay/faymcp/mcp_service.py
# util.log(1, f"已断开服务器 {server['name']} (ID: {server_id}) 的旧连接")
```

---

## Common Mistakes and Gaps

- There is no structured JSON logging pipeline. Do not introduce structured logging for one module unless the project adopts it broadly.
- In core/runtime modules, prefer `util.log` or `util.printInfo` so messages reach the same console/WebSocket/file flow as existing code.
- In standalone MCP servers that already use `logger`, continue using that local logger.
- Avoid relying on Flask/Werkzeug request logs in `gui/flask_server.py`; they are intentionally disabled:

```python
# D:/Projects/GitHub/forks/Fay/gui/flask_server.py
__app.logger.disabled = True
log = logging.getLogger('werkzeug')
log.disabled = True
__app.config['PROPAGATE_EXCEPTIONS'] = True
```
