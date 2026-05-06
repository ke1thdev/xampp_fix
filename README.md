# 🛠️ XAMPP MySQL Auto-Fix

A one-click Windows batch script that automatically diagnoses and repairs the most common XAMPP MySQL/MariaDB startup failures — no technical knowledge required.

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

| Problem | Fix Applied |
|---|---|
| MySQL crashes silently with no clear error | Repairs corrupted Aria system tables |
| `Table '.\mysql\db' is marked as crashed` | `aria_chk --recover --force` on all system tables |
| Stale PID file blocking restart | Deletes `mysql.pid` |
| InnoDB redo log corruption | Deletes `ib_logfile0` / `ib_logfile1` (auto-recreated) |
| Stale `mysqld.exe` zombie process | Force-kills before repair |
| MySQL starts but XAMPP shows it as stopped | Verifies process is actually running after start |

---

## 🔍 Root Cause This Was Built For

XAMPP's MySQL panel shows **"stopped"** but the error log looks completely clean — ending at:

```
[Note] Server socket created on IP: '::'
```

No `[ERROR]` line. No obvious crash. Running `mysqld.exe --console` directly reveals the real error:

```
[ERROR] mysqld.exe: Table '.\mysql\db' is marked as crashed and last (automatic?) repair failed
[ERROR] Fatal error: Can't open and lock privilege tables: Table '.\mysql\db' is marked as crashed and last (automatic?) repair failed
[ERROR] Aborting
```

The `mysql.db` privilege table (and sometimes others like `proxies_priv`, `roles_mapping`) uses the **Aria storage engine** — not MyISAM. When these get corrupted (usually from an abrupt shutdown, Windows Defender interference, or a Windows Update mid-session), MySQL cannot load its privilege system and hard-aborts before logging anything useful.

The crash dump (`mysqld.dmp`) typically shows:
```
InnoDB: File (unknown): 'read' returned OS error 403. Cannot continue operation
```

**OS error 403** on Windows = `ERROR_NETNAME_DELETED` — a file handle was invalidated mid-read, most commonly caused by antivirus/Defender scanning a data file while MySQL holds it open.

---

## 🔒 Is This Safe? What Does It Touch?

**Safe. It never touches your databases or project files.**

✅ **What the script modifies:**
- `mysql.pid` — a temp file MySQL auto-recreates on every startup
- `ib_logfile0` / `ib_logfile1` — InnoDB redo logs that MySQL auto-recreates
- Aria system tables inside `mysql/data/mysql/` — *repaired only*, data is preserved

❌ **What the script never touches:**
- Your database folders (`mysql/data/yourdb/`)
- `ibdata1` — your actual InnoDB table data
- `my.ini` — your MySQL configuration
- Anything inside `htdocs/` — your PHP/HTML project files
- Apache, FileZilla, Mercury, or any other XAMPP component

The `aria_chk --recover` command is the exact same repair routine MySQL runs internally on a crashed table — we just run it manually before MySQL tries to start.

---

## 📋 What the Script Does Step by Step

```
[1/6] Stop any running mysqld processes
      → taskkill /f /im mysqld.exe
      → Prevents file lock conflicts during repair

[2/6] Remove stale PID file
      → Deletes mysql/data/mysql.pid if it exists
      → A leftover PID from a crash can block a clean restart

[3/6] Remove InnoDB redo log files
      → Deletes ib_logfile0 and ib_logfile1
      → MariaDB recreates these automatically
      → Fixes "log sequence number mismatch" crashes

[4/6] Repair all Aria system tables
      → Runs aria_chk --recover --force on:
         db, global_priv, user, tables_priv, columns_priv,
         procs_priv, proxies_priv, roles_mapping, servers,
         func, plugin, proc, event
      → Only repairs tables that actually exist

[5/6] Check available disk space
      → Displays free space on the data drive
      → Low disk space is a common silent crash cause

[6/6] Start MySQL
      → Launches via xampp_start.exe or net start mysql
      → Waits 3 seconds then verifies mysqld.exe is running
      → Prints success URL or fallback debug command
```

---

## 🖥️ Requirements

- Windows 10 / 11
- XAMPP installed at `C:\xampp` (default path)
- MariaDB 10.x (included with XAMPP)

> If your XAMPP is installed in a different location, open `xampp_fix.bat` in Notepad and change the path on line 6:
> ```bat
> set XAMPP=C:\xampp
> ```

---

## 🚑 If The Script Doesn't Fix It

Run MySQL directly in console mode to see the raw error:

```cmd
"C:\xampp\mysql\bin\mysqld.exe" --console
```

Look for any `[ERROR]` lines — they will name the exact file or table causing the crash. Common next steps based on the error:

| Error Message | Next Step |
|---|---|
| `Table '.\mysql\X' is marked as crashed` | Run `aria_chk` manually on that specific table |
| `InnoDB: Corruption in the InnoDB tablespace` | Restore from backup or use `innodb_force_recovery` |
| `Can't start server: Bind on TCP/IP port` | Another process owns port 3306 — check `netstat -ano \| findstr :3306` |
| `The system cannot find the path specified` | XAMPP path mismatch — update the `set XAMPP=` line in the script |

---

## 🛡️ Prevention Tips

1. **Always stop XAMPP properly** before shutting down Windows — use the XAMPP Control Panel Stop buttons, don't just close the window
2. **Add Windows Defender exclusions** for `C:\xampp\` — Defender scanning InnoDB/Aria files mid-write is a leading cause of corruption
3. **Never force-shutdown Windows** while XAMPP is running

---

## 📄 License

MIT — use it, modify it, share it.

---

<p align="center">Made with 🩹 and too many hours of debugging</p>
