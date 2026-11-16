import json
import os
import re
import shutil
import subprocess
import tempfile
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

LABS = Path(os.environ.get("LABS_DIR", "/opt/labs"))
WORK = Path(os.environ.get("LAB_WORKDIR", "/home/coder/lab"))
ACTIVE = WORK.parent / ".active-lab"
STATE = WORK.parent / ".lab-state"
MOTO = os.environ.get("AWS_ENDPOINT_URL", "http://moto:5000")


def run(script, env=None, timeout=300):
    try:
        p = subprocess.run(["bash", str(script)], cwd=WORK, env={**os.environ, **(env or {})},
                           capture_output=True, text=True, timeout=timeout)
        return p.returncode == 0, (p.stdout + p.stderr)[-4000:]
    except subprocess.TimeoutExpired:
        return False, f"timed out after {timeout}s"


def lab(lab_id):
    if not re.fullmatch(r"[a-z0-9-]+", lab_id) or not (LABS / lab_id / "lab.json").is_file():
        return None
    return json.loads((LABS / lab_id / "lab.json").read_text())


def active():
    return ACTIVE.read_text().strip() if ACTIVE.exists() else None


def start(lab_id):
    urllib.request.urlopen(urllib.request.Request(f"{MOTO}/moto-api/reset", method="POST"), timeout=10)
    WORK.mkdir(exist_ok=True)
    shutil.rmtree(STATE, ignore_errors=True)
    STATE.mkdir()
    for child in WORK.iterdir():
        shutil.rmtree(child) if child.is_dir() and not child.is_symlink() else child.unlink()
    files = LABS / lab_id / "files"
    if files.is_dir():
        shutil.copytree(files, WORK, dirs_exist_ok=True)
    ok, output = True, ""
    if (LABS / lab_id / "setup.sh").is_file():
        ok, output = run(LABS / lab_id / "setup.sh", {"LAB_DIR": str(LABS / lab_id), "LAB_STATE": str(STATE)})
    ACTIVE.write_text(lab_id if ok else "")
    return {"ok": ok, "output": output, "active": active()}


def check(lab_id, meta):
    with tempfile.TemporaryDirectory() as tmp:
        results = []
        for task in meta["tasks"]:
            ok, output = run(LABS / lab_id / "checks" / f"{task['id']}.sh",
                             {"LAB_DIR": str(LABS / lab_id), "LAB_STATE": str(STATE), "CHECK_TMP": tmp, "LIB": str(LABS / "lib.sh")}, 180)
            results.append({"id": task["id"], "ok": ok, "output": output.strip()})
    return {"results": results}


class Handler(BaseHTTPRequestHandler):
    def reply(self, code, body):
        data = json.dumps(body).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self):
        if self.path == "/status":
            return self.reply(200, {"active": active()})
        self.reply(404, {"error": "not found"})

    def do_POST(self):
        m = re.fullmatch(r"/labs/([^/]+)/(start|check)", self.path)
        meta = m and lab(m.group(1))
        if not meta:
            return self.reply(404, {"error": "unknown lab"})
        lab_id, action = m.groups()
        if action == "start":
            return self.reply(200, start(lab_id))
        if active() != lab_id:
            return self.reply(409, {"error": "This lab is not running. Start it first."})
        self.reply(200, check(lab_id, meta))


if __name__ == "__main__":
    ThreadingHTTPServer(("0.0.0.0", 7000), Handler).serve_forever()
