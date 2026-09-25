#!/usr/bin/env python3
"""
Single Website Cloud Browser Gateway - Minimal Admin Controller
Supports dual desktop and mobile browser instances.
Listens strictly on 127.0.0.1:8088 and is reverse-proxied by Apache at /admin.
"""

import http.server
import json
import os
import shutil
import socketserver
import subprocess
from pathlib import Path

PORT = 8088
HOST = "127.0.0.1"

# Resolve project paths
SCRIPT_DIR = Path(__file__).resolve().parent
PROJECT_ROOT = SCRIPT_DIR.parent
DATA_DIR = PROJECT_ROOT / "data"
SCRIPTS_DIR = PROJECT_ROOT / "scripts"

def run_cmd(cmd_list):
    """Run a shell command within the project root."""
    try:
        res = subprocess.run(
            cmd_list,
            cwd=str(PROJECT_ROOT),
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            timeout=45
        )
        return res.returncode == 0, res.stdout.strip() or res.stderr.strip()
    except Exception as e:
        return False, str(e)

def get_dir_size(path: Path):
    """Calculate directory size in human-readable format."""
    if not path.exists():
        return "0 MB"
    total_bytes = sum(f.stat().st_size for f in path.glob("**/*") if f.is_file())
    if total_bytes < 1024 * 1024:
        return f"{total_bytes / 1024:.1f} KB"
    return f"{total_bytes / (1024 * 1024):.1f} MB"

def get_container_status(name):
    """Check Docker container status."""
    ok, out = run_cmd(["docker", "inspect", "-f", "{{.State.Status}}", name])
    if ok and out:
        return out.capitalize()
    return "Stopped / Offline"

HTML_TEMPLATE = """<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Browser Gateway Admin</title>
    <style>
        :root {
            --bg: #0f172a;
            --card-bg: #1e293b;
            --border: #334155;
            --text-main: #f8fafc;
            --text-muted: #94a3b8;
            --primary: #3b82f6;
            --primary-hover: #2563eb;
            --danger: #ef4444;
            --danger-hover: #dc2626;
            --warning: #f59e0b;
            --warning-hover: #d97706;
            --success: #10b981;
        }
        * { box-sizing: border-box; margin: 0; padding: 0; font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; }
        body { background: var(--bg); color: var(--text-main); display: flex; justify-content: center; align-items: center; min-height: 100vh; padding: 20px; }
        .card { background: var(--card-bg); border: 1px solid var(--border); border-radius: 14px; width: 100%; max-width: 560px; padding: 28px; box-shadow: 0 20px 25px -5px rgba(0, 0, 0, 0.5); }
        .header { display: flex; align-items: center; justify-content: space-between; margin-bottom: 20px; padding-bottom: 14px; border-bottom: 1px solid var(--border); }
        .header h1 { font-size: 1.25rem; font-weight: 700; color: #fff; }
        .grid-2 { display: grid; grid-template-columns: 1fr 1fr; gap: 12px; margin-bottom: 20px; }
        .instance-card { background: #0f172a; padding: 14px; border-radius: 10px; border: 1px solid var(--border); }
        .instance-title { font-size: 0.85rem; font-weight: 700; text-transform: uppercase; color: #38bdf8; margin-bottom: 8px; display: flex; justify-content: space-between; }
        .stat-line { font-size: 0.8rem; color: var(--text-muted); margin-bottom: 4px; }
        .stat-val { color: var(--text-main); font-weight: 600; }
        .btn-group { display: flex; flex-direction: column; gap: 10px; }
        button { width: 100%; padding: 12px; font-size: 0.95rem; font-weight: 600; border-radius: 8px; border: none; cursor: pointer; transition: all 0.2s; display: flex; align-items: center; justify-content: center; gap: 8px; }
        button:disabled { opacity: 0.5; cursor: not-allowed; }
        .btn-primary { background: var(--primary); color: white; }
        .btn-primary:hover:not(:disabled) { background: var(--primary-hover); }
        .btn-warning { background: var(--warning); color: #000; }
        .btn-warning:hover:not(:disabled) { background: var(--warning-hover); }
        .btn-danger { background: var(--danger); color: white; }
        .btn-danger:hover:not(:disabled) { background: var(--danger-hover); }
        .links-row { display: flex; gap: 10px; margin-top: 6px; }
        .btn-link { background: #334155; color: #f8fafc; padding: 8px; font-size: 0.85rem; text-decoration: none; border-radius: 6px; text-align: center; flex: 1; display: inline-block; }
        .btn-link:hover { background: #475569; }
        #feedback { margin-top: 18px; padding: 12px; border-radius: 8px; font-size: 0.85rem; display: none; }
        .alert-ok { background: #064e3b; color: #a7f3d0; border: 1px solid #059669; }
        .alert-err { background: #450a0a; color: #fecaca; border: 1px solid #b91c1c; }
    </style>
</head>
<body>
    <div class="card">
        <div class="header">
            <h1>Gateway Dashboard</h1>
            <span style="font-size: 0.75rem; color: #94a3b8;">Dual Desktop &amp; Mobile</span>
        </div>

        <div class="grid-2">
            <div class="instance-card">
                <div class="instance-title">
                    <span>🖥️ Desktop</span>
                    <span style="color: {{DESK_COLOR}};">● {{DESK_STATUS}}</span>
                </div>
                <div class="stat-line">Resolution: <span class="stat-val">1920x1080</span></div>
                <div class="stat-line">Profile Size: <span class="stat-val">{{DESK_SIZE}}</span></div>
                <div class="links-row">
                    <a href="/desktop" class="btn-link" target="_blank">Open Desktop &rarr;</a>
                </div>
            </div>

            <div class="instance-card">
                <div class="instance-title">
                    <span>📱 Mobile</span>
                    <span style="color: {{MOB_COLOR}};">● {{MOB_STATUS}}</span>
                </div>
                <div class="stat-line">Resolution: <span class="stat-val">412x915 (Touch)</span></div>
                <div class="stat-line">Profile Size: <span class="stat-val">{{MOB_SIZE}}</span></div>
                <div class="links-row">
                    <a href="/mobile" class="btn-link" target="_blank">Open Mobile &rarr;</a>
                </div>
            </div>
        </div>

        <div class="btn-group">
            <button class="btn-primary" onclick="triggerAction('restart')">
                <span>🔄</span> Restart Both Browsers
            </button>
            <button class="btn-warning" onclick="triggerAction('clear_cache')">
                <span>🗑️</span> Clear Cache Only (Keep Logins)
            </button>
            <button class="btn-primary" style="background: #0284c7;" onclick="triggerAction('backup')">
                <span>💾</span> Backup All Profiles
            </button>
            <button class="btn-danger" onclick="confirmReset()">
                <span>⚠️</span> Reset All Sessions (Logout &amp; Fresh State)
            </button>
        </div>

        <div id="feedback"></div>
    </div>

    <script>
        function showMsg(text, isError = false) {
            const el = document.getElementById('feedback');
            el.className = isError ? 'alert-err' : 'alert-ok';
            el.innerText = text;
            el.style.display = 'block';
        }

        async function triggerAction(action) {
            const buttons = document.querySelectorAll('button');
            buttons.forEach(b => b.disabled = true);
            showMsg('Executing command, please wait...');

            try {
                const res = await fetch('/admin/api/' + action, { method: 'POST' });
                const data = await res.json();
                if (data.success) {
                    showMsg(data.message || 'Operation successful!');
                    setTimeout(() => location.reload(), 2000);
                } else {
                    showMsg('Error: ' + data.message, true);
                    buttons.forEach(b => b.disabled = false);
                }
            } catch (err) {
                showMsg('Request failed: ' + err, true);
                buttons.forEach(b => b.disabled = false);
            }
        }

        function confirmReset() {
            if (confirm("Are you sure you want to RESET all sessions?\\n\\nThis will remove logins on BOTH Desktop and Mobile instances.")) {
                triggerAction('reset');
            }
        }
    </script>
</body>
</html>
"""

class AdminHandler(http.server.BaseHTTPRequestHandler):
    def _send_json(self, data, code=200):
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        self.wfile.write(json.dumps(data).encode("utf-8"))

    def do_GET(self):
        desk_stat = get_container_status("cloud-browser-desktop")
        mob_stat = get_container_status("cloud-browser-mobile")

        desk_size = get_dir_size(DATA_DIR / "profile-desktop")
        mob_size = get_dir_size(DATA_DIR / "profile-mobile")

        desk_color = "#34d399" if desk_stat.lower() == "running" else "#f87171"
        mob_color = "#34d399" if mob_stat.lower() == "running" else "#f87171"

        page = HTML_TEMPLATE\
            .replace("{{DESK_STATUS}}", desk_stat)\
            .replace("{{MOB_STATUS}}", mob_stat)\
            .replace("{{DESK_SIZE}}", desk_size)\
            .replace("{{MOB_SIZE}}", mob_size)\
            .replace("{{DESK_COLOR}}", desk_color)\
            .replace("{{MOB_COLOR}}", mob_color)

        self.send_response(200)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.end_headers()
        self.wfile.write(page.encode("utf-8"))

    def do_POST(self):
        path = self.path.rstrip("/")

        if path in ("/admin/api/restart", "/api/restart"):
            ok, out = run_cmd(["docker", "compose", "restart", "browser-desktop", "browser-mobile"])
            self._send_json({"success": ok, "message": "Both browser instances restarted." if ok else out})

        elif path in ("/admin/api/reset", "/api/reset"):
            reset_script = SCRIPTS_DIR / "reset-session.sh"
            ok, out = run_cmd(["bash", str(reset_script), "all"])
            self._send_json({"success": ok, "message": "Sessions wiped on both Desktop and Mobile!" if ok else out})

        elif path in ("/admin/api/backup", "/api/backup"):
            backup_script = SCRIPTS_DIR / "backup.sh"
            ok, out = run_cmd(["bash", str(backup_script)])
            self._send_json({"success": ok, "message": "Backup created successfully in backups/ folder" if ok else out})

        elif path in ("/admin/api/clear_cache", "/api/clear_cache"):
            cleared = 0
            for profile in [DATA_DIR / "profile-desktop", DATA_DIR / "profile-mobile"]:
                for c in [profile / "Default" / "Cache", profile / "Default" / "Code Cache"]:
                    if c.exists():
                        shutil.rmtree(c, ignore_errors=True)
                        cleared += 1
            self._send_json({"success": True, "message": f"Cache directories cleared ({cleared} caches removed)."})

        else:
            self._send_json({"success": False, "message": "Unknown endpoint"}, 404)

    def log_message(self, format, *args):
        pass

if __name__ == "__main__":
    print(f"Starting Gateway Admin Server on http://{HOST}:{PORT}")
    with socketserver.TCPServer((HOST, PORT), AdminHandler) as httpd:
        httpd.serve_forever()
