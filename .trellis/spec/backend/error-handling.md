# Error Handling

> How errors are handled in this project.

---

## Overview

The project primarily uses local `try`/`except` blocks and returns simple dictionaries, JSON responses, fallback values, or booleans. There are no project-wide custom exception classes or central Flask error handlers observed. Errors are usually logged with `utils.util.log(...)`, `logger.error(...)`, or `print(...)` depending on the module.

Document the behavior that exists today rather than introducing a new exception hierarchy.

---

## Error Types

No custom domain error classes were found. Existing code handles:

- `json.JSONDecodeError` for malformed request payloads in Flask routes.
- `sqlite3.IntegrityError` for duplicate adopted message records.
- `ImportError` for optional runtime dependencies.
- Broad `Exception` for IO, network, device, MCP, DB, and external API failures.

Observed examples:

```python
# D:/Projects/GitHub/forks/Fay/gui/flask_server.py
except json.JSONDecodeError:
    return jsonify({'result': 'error', 'message': '无效的JSON数据'})
except Exception as e:
    return jsonify({'result': 'error', 'message': f'保存配置时出错: {e}'}), 500
```

```python
# D:/Projects/GitHub/forks/Fay/core/content_db.py
except sqlite3.IntegrityError:
    util.log(1, "该消息已被采纳")
    conn.close()
    return False
```

```python
# D:/Projects/GitHub/forks/Fay/mcp_servers/schedule_manager/server.py
try:
    from mcp.server import Server
    from mcp.types import Resource, Tool, TextContent, ImageContent, EmbeddedResource
    import mcp.server.stdio
    from pydantic import AnyUrl
except ImportError:
    print("MCP库未安装，请运行: pip install mcp")
    sys.exit(1)
```

---

## Error Handling Patterns

### Handle errors at the boundary and return existing response shapes

Flask APIs generally validate inputs and return `jsonify(...)` with either an error field or a `success: False` payload. Some older routes return JSON strings for success.

```python
# D:/Projects/GitHub/forks/Fay/faymcp/mcp_service.py
if transport == 'stdio':
    if 'name' not in data or 'command' not in data:
        return jsonify({"error": "缺少必要字段: name 或 command"}), 400
else:
    required_fields = ['name', 'ip']
    for field in required_fields:
        if field not in data:
            return jsonify({"error": f"缺少必要字段: {field}"}), 400
```

```python
# D:/Projects/GitHub/forks/Fay/mcp_servers/schedule_manager/web_server.py
if not data:
    return jsonify({"success": False, "message": "无效的请求数据"})

if not title or not schedule_time:
    return jsonify({"success": False, "message": "标题和时间为必填项"})
```

### Service methods return fallback values instead of propagating exceptions

Database and service methods frequently catch exceptions, log or embed the error message, and return a neutral fallback.

```python
# D:/Projects/GitHub/forks/Fay/core/content_db.py
try:
    cur.execute("UPDATE T_Msg SET content = ?, createtime = ? WHERE id = ?", (content, now_ms, msg_id))
    conn.commit()
    affected_rows = cur.rowcount
except Exception as e:
    util.log(1, f"更新消息内容失败: {e}")
    conn.close()
    return 0
conn.close()
return now_ms if affected_rows > 0 else 0
```

```python
# D:/Projects/GitHub/forks/Fay/mcp_servers/schedule_manager/server.py
except Exception as e:
    logger.error(f"获取日程列表失败: {e}")
    return []
```

### Optional integrations degrade gracefully

Optional imports and tracing integrations catch initialization/finalization failures and continue.

```python
# D:/Projects/GitHub/forks/Fay/gui/flask_server.py
try:
    from langsmith.run_trees import RunTree
except Exception:
    RunTree = None
```

```python
# D:/Projects/GitHub/forks/Fay/gui/flask_server.py
except Exception as exc:
    util.log(2, f"LangSmith proxy tracing init failed: {exc}")
    return None
```

### Cleanup code catches and logs individual failures

Shutdown and disconnect paths avoid letting one cleanup failure prevent later cleanup.

```python
# D:/Projects/GitHub/forks/Fay/main.py
try:
    from scheduler.thread_manager import stopAll
    util.log(1, '正在停止所有线程...')
    stopAll()
    util.log(1, '所有线程已停止')
except Exception as e:
    util.log(1, f'停止线程时出错: {e}')
```

---

## API Error Responses

There is not one global response envelope. Match the route/module's existing style:

- Main UI routes in `gui/flask_server.py` often use `{'result': 'error', 'message': '...'}` and return HTTP 500 for unexpected failures.
- MCP management routes in `faymcp/mcp_service.py` often use `{"error": "..."}` for validation/not-found errors, or `{"success": False, "message": "..."}` for connection/update flows.
- Schedule manager APIs use `{"success": False, "message": "..."}`.

Examples:

```python
# D:/Projects/GitHub/forks/Fay/gui/flask_server.py
return jsonify({'result': 'error', 'message': f'发送消息时出错: {e}'}), 500
```

```python
# D:/Projects/GitHub/forks/Fay/faymcp/mcp_service.py
return jsonify({"error": "服务器未找到"}), 404
```

```python
# D:/Projects/GitHub/forks/Fay/mcp_servers/schedule_manager/server.py
return {"success": False, "message": "时间格式错误，请使用 HH:MM 格式（如 09:30）"}
```

---

## Common Mistakes and Gaps

- Do not add a new global exception framework for a small change; no central framework exists today.
- Do not return a new response envelope from an existing route family. Match the local route style.
- When manually opening resources, close them on error paths too. Existing DB code frequently calls `conn.close()` before returning from `except` blocks.
- Some existing code intentionally swallows non-critical cleanup/disconnect errors (for example, old MCP disconnect cleanup). Keep silent `pass` limited to cleanup or best-effort optional paths; otherwise log or return an error message.
