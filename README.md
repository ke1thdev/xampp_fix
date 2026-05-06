# 🛠️ XAMPP MySQL Auto-Fix

A one-click Windows batch script that automatically detects and repairs the most common XAMPP MySQL/MariaDB startup failures — no technical knowledge required.

> Built out of frustration after spending hours debugging a silent MariaDB crash caused by a corrupted Aria system table. If it saved me the headache, maybe it saves you too.

---

## ⚡ Quick Start

1. Download `xampp_fix.bat`
2. Right-click → **Run as administrator**
3. Wait for the script to finish
4. Open `http://localhost/phpmyadmin` ✅

The script auto-elevates to admin if you forget.

---

## 🧩 What It Fixes

| # | Check | What It Does |
|---|---|---|
| 1 | Stale `mysqld.exe` process | Force-kills any zombie MySQL processes before repair |
| 2 | Stale PID file | Deletes `mysql.pid` leftover from a crash |
| 3 | Port 3306 conflict | Detects and kills whatever process is holding the port |
| 4 | Low disk space | Warns if less than 500MB free (MySQL needs space for temp files) |
| 5 | InnoDB redo log corruption | Removes `ib_logfile0` / `ib_logfile1` — auto-recreated on start |
| 6 | Aria system table corruption | Checks then repairs `.MAI`/`.MAD` tables (MariaDB 10.x) |
| 7 | MyISAM system table corruption | Checks then repairs `.MYI`/`.MYD` tables (older XAMPP/MySQL) |
| 8 | Temp and lock files | Removes `ibtmp1` and any stale `.lock` files |
| 9 | MySQL startup | Launches MySQL via XAMPP or Windows service |
| 10 | Verification | Confirms `mysqld.exe` is actually running after all fixes |

> Steps 6 and 7 **check first, repair only if needed** — healthy tables are never touched.

---

## 🔍 The Root Cause This Was Built For

XAMPP's MySQL panel shows **"stopped"** but the error log looks completely clean — ending at:

```
[Note] Server socket created on IP: '::'
```

No `[ERROR]` line. Running `mysqld.exe --console` directly reveals the real error hidden from the log:

```
[ERROR] mysqld.exe: Table '.\mysql\db' is marked as crashed and last (automatic?) repair failed
[ERROR] Fatal error: Can't open and lock privilege tables: Table '.\mysql\db' is marked as crashed
[ERROR] Aborting
```

The `mysql.db` privilege table (and others like `proxies_priv`, `roles_mapping`) uses the **Aria storage engine** — not MyISAM. When these get corrupted from an abrupt shutdown, Windows Defender interference, or a Windows Update mid-session, MySQL cannot load its privilege system and hard-aborts before logging anything useful.

The crash dump (`mysqld.dmp`) typically shows:
```
InnoDB: File (unknown): 'read' returned OS error 403. Cannot continue operation
```

**OS error 403** on Windows = `ERROR_NETNAME_DELETED` — a file handle was invalidated mid-read, most commonly caused by antivirus scanning a data file while MySQL holds it open.

---

## 🔒 Is This Safe? What Does It Touch?

**Safe. It never touches your databases or project files.**

✅ **What the script modifies:**
- `mysql.pid` — a temp file MySQL auto-recreates on every startup
- `ib_logfile0` / `ib_logfile1` — InnoDB redo logs MySQL auto-recreates
- `ibtmp1` — InnoDB temp tablespace, auto-recreated on startup
- `*.lock` files — stale lock files from crashed sessions
- Aria/MyISAM system tables inside `mysql/data/mysql/` — **repaired only if corrupted**, data is preserved

❌ **What the script never touches:**
- Your database folders (`mysql/data/yourdb/`)
- `ibdata1` — your actual InnoDB table data
- Individual `.ibd` table files
- `my.ini` — your MySQL configuration
- Anything inside `htdocs/` — your PHP/HTML/project files
- Apache, FileZilla, Mercury, or any other XAMPP component

---

## 📋 Script Flow

```
[1]  Kill stale mysqld.exe
[2]  Delete mysql.pid
[3]  Detect & kill port 3306 conflict
[4]  Check disk space (warn if < 500MB)
[5]  Delete ib_logfile0 / ib_logfile1
[6]  Check → Repair Aria tables (.MAI/.MAD)
       db, global_priv, user, tables_priv, columns_priv,
       procs_priv, proxies_priv, roles_mapping, servers,
       func, plugin, proc, event, time_zone, help_topic...
[7]  Check → Repair MyISAM tables (.MYI/.MYD)
       Same table list for older XAMPP/MySQL installs
[8]  Remove ibtmp1 and *.lock files
[9]  Start MySQL (xampp_start.exe or net start mysql)
[10] Verify mysqld.exe is running → print result
```

---

## 🖥️ Requirements

- Windows 10 / 11
- XAMPP installed at `C:\xampp` (default path)
- MariaDB 10.x or MySQL 5.x (both included with XAMPP)

> If your XAMPP is installed somewhere else, open `xampp_fix.bat` in Notepad and change line 6:
> ```bat
> set XAMPP=C:\your\path\to\xampp
> ```

---

## 🚑 If The Script Doesn't Fix It

Run MySQL in console mode to see the raw error output:

```cmd
"C:\xampp\mysql\bin\mysqld.exe" --console
```

Look for `[ERROR]` lines — they name the exact file or table causing the crash.

| Error | Next Step |
|---|---|
| `Table '.\mysql\X' is marked as crashed` | Run `aria_chk` or `myisamchk` manually on that specific table |
| `InnoDB: Corruption in the InnoDB tablespace` | Restore from backup or use `innodb_force_recovery=1` in `my.ini` |
| `Can't start server: Bind on TCP/IP port` | Something still owns port 3306 — check `netstat -ano \| findstr :3306` |
| `The system cannot find the path` | XAMPP path mismatch — update `set XAMPP=` in the script |
| `OS error 403` in `mysqld.dmp` | Windows Defender quarantined a file — check **Windows Security → Protection History → Restore** |

---

## 🛡️ Prevention Tips

1. **Always stop XAMPP properly** before shutting down Windows — use the Control Panel Stop buttons, never just close the window or force shutdown
2. **Add Windows Defender exclusions** for `C:\xampp\` — Defender scanning Aria/InnoDB files mid-write is a leading cause of silent corruption
   > Windows Security → Virus & threat protection → Manage settings → Exclusions → Add folder → `C:\xampp`
3. **Keep disk space healthy** — MySQL needs free space to write temp and log files

---

## 📄 License

MIT — use it, modify it, share it freely.

---

<p align="center">Made with 🩹 and too many hours of debugging</p>
