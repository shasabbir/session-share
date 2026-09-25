#!/usr/bin/env python3
"""
Single Website Cloud Browser Gateway - Minimal Admin Controller
A zero-dependency administrative micro-server using Python's built-in standard library.
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
PROFILE_DIR = PROJECT_ROOT / "data" / "chromium-profile"
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

def get_profile_size():
    """Calculate profile folder size in human-readable format."""
    if not PROFILE_DIR.exists():
        return "0 MB"
    total_bytes = sum(f.stat().st_size for f in PROFILE_DIR.glob("**/*") if f.is_file())
    if total_bytes < 1024 * 1024:
        return f"{total_bytes / 1024:.1f} KB"
    return f"{total_bytes / (1024 * 1024):.1f} MB"

def get_container_status():
    """Check Docker container status."""
    ok, out = run_cmd(["docker", "compose", "ps", "--format", "json"])
    if not ok or not out:
        return "Unknown / Stopped"
    try:
        data = json.loads(out)
        if isinstance(data, list) and len(data) > 0:
            return data[0].get("State", "Unknown")
        elif isinstance(data, dict):
            return data.get("State", "Unknown")
    except Exception:
        pass
    return "Running" if "cloud-browser" in out or "Up" in out else "Stopped"

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
        .card { background: var(--card-bg); border: 1px solid var(--border); border-radius: 14px; width: 100%; max-width: 520px; padding: 28px; box-shadow: 0 20px 25px -5px rgba(0, 0, 0, 0.5); }
        .header { display: flex; align-items: center; justify-content: space-between; margin-bottom: 24px; padding-bottom: 16px; border-bottom: 1px solid var(--border); }
        .header h1 { font-size: 1.25rem; font-weight: 700; color: #fff; }
        .badge { display: inline-flex; align-items: center; gap: 6px; padding: 4px 10px; border-radius: 9999px; font-size: 0.75rem; font-weight: 600; text-transform: uppercase; background: #064e3b; color: #6ee7b7; }
        .stats-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 12px; margin-bottom: 24px; }
        .stat-item { background: #0f172a; padding: 12px; border-radius: 8px; border: 1px solid var(--border); }
        .stat-label { font-size: 0.75rem; color: var(--text-muted); text-transform: uppercase; margin-bottom: 4px; }
        .stat-val { font-size: 1.1rem; font-weight: 600; }
        .btn-group { display: flex; flex-direction: column; gap: 10px; }
        button { width: 100%; padding: 12px; font-size: 0.95rem; font-weight: 600; border-radius: 8px; border: none; cursor: pointer; transition: all 0.2s; display: flex; align-items: center; justify-content: center; gap: 8px; }
        button:disabled { opacity: 0.5; cursor: not-allowed; }
        .btn-primary { background: var(--primary); color: white; }
        .btn-primary:hover:not(:disabled) { background: var(--primary-hover); }
        .btn-warning { background: var(--warning); color: #000; }
        .btn-warning:hover:not(:disabled) { background: var(--warning-hover); }
        .btn-danger { background: var(--danger); color: white; }
        .btn-danger:hover:not(:disabled) { background: var(--danger-hover); }
        .btn-link { background: transparent; border: 1px solid var(--border); color: var(--text-muted); }
        .btn-link:hover:not(:disabled) { background: #334155; color: white; }
        #feedback { margin-top: 18px; padding: 12px; border-radius: 8px; font-size: 0.85rem; display: none; }
        .alert-ok { background: #064e3b; color: #a7f3d0; border: 1px solid #059669; }
        .alert-err { background: #450a0a; color: #fecaca; border: 1px solid #b91c1c; }
    </style>
</head>
<body>
    <div class="card">
        <div class="header">
            <h1>Gateway Admin</h1>
            <span class="badge" id="status-badge">● Container: {{STATUS}}</span>
        </div>

        <div class="stats-grid">
            <div class="stat-item">
                <div class="stat-label">Profile Storage</div>
                <div class="stat-val" id="profile-size">{{PROFILE_SIZE}}</div>
            </div>
            <div class="stat-item">
                <div class="stat-label">Quick Link</div>
                <div class="stat-val"><a href="/example.com" style="color: var(--primary); text-decoration: none;">Open Browser &rarr;</a></div>
            </div>
        </div>

        <div class="btn-group">
            <button class="btn-primary" onclick="triggerAction('restart')">
                <span>🔄</span> Restart Browser
            </button>
            <button class="btn-warning" onclick="triggerAction('clear_cache')">
                <span>🗑️</span> Clear Browser Cache Only
            </button>
            <button class="btn-primary" style="background: #0284c7;" onclick="triggerAction('backup')">
                <span>💾</span> Backup Profile Now
            </button>
            <button class="btn-danger" onclick="confirmReset()">
                <span>⚠️</span> Reset Session (Logout / Fresh State)
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
            if (confirm("Are you sure you want to RESET the session?\\n\\nThis will remove all cookies, login tokens, and cache. You will need to log into the website again.")) {
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
        # Serve UI
        status = get_container_status()
        size = get_profile_size()
        page = HTML_TEMPLATE.replace("{{STATUS}}", status).replace("{{PROFILE_SIZE}}", size)

        self.send_response(200)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.end_headers()
        self.wfile.write(page.encode("utf-8"))

    def do_POST(self):
        path = self.path.rstrip("/")

        if path == "/admin/api/restart" or path == "/api/restart":
            ok, out = run_cmd(["docker", "compose", "restart", "browser"])
            self._send_json({"success": ok, "message": out if ok else "Failed to restart container: " + out})

        elif path == "/admin/api/reset" or path == "/api/reset":
            reset_script = SCRIPTS_DIR / "reset-session.sh"
            ok, out = run_cmd(["bash", str(reset_script)])
            self._send_json({"success": ok, "message": "Session wiped and browser restarted!" if ok else out})

        elif path == "/admin/api/backup" or path == "/api/backup":
            backup_script = SCRIPTS_DIR / "backup.sh"
            ok, out = run_cmd(["bash", str(backup_script)])
            self._send_json({"success": ok, "message": "Backup created successfully in backups/ folder" if ok else out})

        elif path == "/admin/api/clear_cache" or path == "/api/clear_cache":
            # Clear cache without logging out
            cache_dirs = [
                PROFILE_DIR / "Default" / "Cache",
                PROFILE_DIR / "Default" / "Code Cache",
                PROFILE_DIR / "Default" / "GPUCache"
            ]
            cleared = 0
            for c in cache_dirs:
                if c.exists():
                    shutil.rmtree(c, ignore_errors=True)
                    cleared += 1
            self._send_json({"success": True, "message": f"Cache directories cleared ({cleared} caches removed)."})

        else:
            self._send_json({"success": False, "message": "Unknown endpoint"}, 404)

    def log_message(self, format, *args):
        # Clean logging
        pass

if __name__ == "__main__":
    print(f"Starting Gateway Admin Server on http://{HOST}:{PORT}")
    with socketserver.TCPServer((HOST, PORT), AdminHandler) as httpd:
        httpd.serve_forever()
