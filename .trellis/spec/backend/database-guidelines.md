# Database Guidelines

> Database patterns and conventions for this project.

---

## Overview

The project uses Python's built-in `sqlite3` module directly. No ORM, migration tool, or migration framework was found. Tables are created or evolved at runtime inside repository/service classes with `CREATE TABLE IF NOT EXISTS`, `PRAGMA table_info`, and occasional `ALTER TABLE` compatibility checks.

Primary observed SQLite files:

- `memory/fay.db` - conversation history and authorization tables (`core/content_db.py`, `core/authorize_tb.py`).
- `memory/user_profiles.db` - user profile table (`core/member_db.py`).
- `mcp_servers/schedule_manager/schedules.db` at runtime - schedule manager data (`mcp_servers/schedule_manager/server.py`, `web_server.py`).

---

## Query Patterns

### Open a short-lived connection per operation

Database methods generally open a connection, create a cursor, execute one operation or a small group of related operations, commit when mutating, then close the connection explicitly.

```python
# D:/Projects/GitHub/forks/Fay/core/member_db.py
conn = sqlite3.connect('memory/user_profiles.db')
c = conn.cursor()
c.execute('UPDATE T_Member SET username = ? WHERE username = ?', (new_username, username))
conn.commit()
conn.close()
return "success"
```

```python
# D:/Projects/GitHub/forks/Fay/core/content_db.py
conn = sqlite3.connect("memory/fay.db")
conn.text_factory = str
cur = conn.cursor()
cur.execute("SELECT * FROM T_Msg WHERE id = ?", (msg_id,))
record = cur.fetchone()
conn.close()
return record
```

### Use positional parameters for external values

Most queries use SQLite parameter placeholders (`?`) for user-provided values.

```python
# D:/Projects/GitHub/forks/Fay/core/content_db.py
cur.execute(
    """
    SELECT type, content
    FROM T_Msg
    WHERE username = ?
    ORDER BY id DESC
    LIMIT ?
    """,
    (username, limit),
)
```

```python
# D:/Projects/GitHub/forks/Fay/mcp_servers/schedule_manager/server.py
cursor.execute(
    "INSERT INTO schedules (title, content, schedule_time, repeat_rule, created_at, updated_at, uid) VALUES (?, ?, ?, ?, ?, ?, ?)",
    (title, content, schedule_time, repeat_rule, now, now, uid)
)
```

### Dynamically build only controlled SQL fragments

Some methods build SQL fragments for generated placeholder lists or values controlled by the caller's route/service. Keep this pattern narrow and prefer placeholders or explicit whitelists for any value that can originate from a request.

```python
# D:/Projects/GitHub/forks/Fay/core/content_db.py
if same_content_ids:
    placeholders = ','.join('?' * len(same_content_ids))
    cur.execute(f"DELETE FROM T_Adopted WHERE msg_id IN ({placeholders})", same_content_ids)
    conn.commit()
```

```python
# D:/Projects/GitHub/forks/Fay/mcp_servers/schedule_manager/server.py
updates.append("updated_at = ?")
params.append(datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S'))
params.append(schedule_id)

cursor.execute(f"UPDATE schedules SET {', '.join(updates)} WHERE id = ?", params)
```

Existing legacy code also interpolates `order` and `uid` in `core/content_db.py#get_list` / `get_message_count`; current callers pass controlled values such as `'desc'` from `gui/flask_server.py`. Do not copy that pattern for raw request values.

### Protect shared DB wrapper methods with locks

Core DB wrapper classes use a local `threading.Lock` and a `@synchronized` decorator around mutating and list/query methods.

```python
# D:/Projects/GitHub/forks/Fay/core/content_db.py
def synchronized(func):
    @functools.wraps(func)
    def wrapper(self, *args, **kwargs):
        with self.lock:
            return func(self, *args, **kwargs)
    return wrapper

class Content_Db:
    def __init__(self) -> None:
        self.lock = threading.Lock()

    @synchronized
    def add_content(self, type, way, content, username='User', uid=0):
        ...
```

---

## Migrations and Schema Changes

There is no separate migration directory. Schema initialization happens when services start or repository singletons are first created.

```python
# D:/Projects/GitHub/forks/Fay/core/content_db.py
def init_db(self):
    conn = sqlite3.connect('memory/fay.db')
    conn.text_factory = str
    c = conn.cursor()
    c.execute('''CREATE TABLE IF NOT EXISTS T_Msg
        (id INTEGER PRIMARY KEY AUTOINCREMENT,
        type        CHAR(10),
        way         CHAR(10),
        content     TEXT    NOT NULL,
        createtime  INT,
        username    TEXT DEFAULT 'User',
        uid         INT);''')
    conn.commit()
    conn.close()
```

Backward-compatible column additions are handled inline by checking the existing table shape.

```python
# D:/Projects/GitHub/forks/Fay/core/member_db.py
c.execute("PRAGMA table_info(T_Member)")
columns = [column[1] for column in c.fetchall()]
if 'extra_info' not in columns:
    c.execute('ALTER TABLE T_Member ADD COLUMN extra_info TEXT DEFAULT ""')
if 'user_portrait' not in columns:
    c.execute('ALTER TABLE T_Member ADD COLUMN user_portrait TEXT DEFAULT ""')
```

Schedule manager creates its own schema in both MCP and Web server variants.

```python
# D:/Projects/GitHub/forks/Fay/mcp_servers/schedule_manager/web_server.py
cursor.execute('''
    CREATE TABLE IF NOT EXISTS schedules (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        content TEXT NOT NULL,
        schedule_time TEXT NOT NULL,
        repeat_rule TEXT NOT NULL DEFAULT '0000000',
        status TEXT NOT NULL DEFAULT 'active',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        uid INTEGER DEFAULT 0
    )
''')
```

---

## Naming Conventions

- Older core tables use `T_` prefixes with Pascal-style names: `T_Msg`, `T_Adopted`, `T_Member`, `T_Authorize`.
- Newer feature tables can be lowercase plural, as seen in schedule manager: `schedules`.
- Common primary key column is `id INTEGER PRIMARY KEY AUTOINCREMENT`.
- Time columns vary by module:
  - `createtime` stores integer Unix timestamps or milliseconds in core tables.
  - `created_at` and `updated_at` store formatted strings in schedule manager.
- User scoping commonly uses `username` and/or `uid` columns.

---

## Common Mistakes and Gaps

- There is no migration runner. If a schema changes, add runtime compatibility logic near the owning `init_db()`/`init_database()` method.
- Do not introduce an ORM for one feature unless the wider project adopts it; all observed persistence code uses direct `sqlite3`.
- Avoid interpolating request/user values directly into SQL. The codebase mostly uses `?` placeholders for external values. A few existing methods interpolate generated placeholders, update fragments, or legacy controlled values; keep new dynamic SQL limited to generated placeholders or whitelisted fragments.
- Always close SQLite connections. Existing methods close connections manually rather than using context managers.
- `core/member_db.py#query(sql)` executes a raw SQL string and returns an error string on failure. Treat it as a legacy helper; do not expose request-controlled SQL to it.
