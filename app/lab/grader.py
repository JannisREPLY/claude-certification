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
EXAM = Path(os.environ.get("EXAM_WORKDIR", "/home/coder/exam"))
ACTIVE = WORK.parent / ".active-lab"
STATE = WORK.parent / ".lab-state"
MOTO = os.environ.get("AWS_ENDPOINT_URL", "http://moto:5000")
LEVELS = ("guided", "exam", "expert")


def run(script, cwd, env=None, timeout=300):
    try:
        p = subprocess.run(["bash", str(script)], cwd=cwd, env={**os.environ, **(env or {})},
                           capture_output=True, text=True, timeout=timeout)
        return p.returncode == 0, (p.stdout + p.stderr)[-4000:]
    except subprocess.TimeoutExpired:
        return False, f"timed out after {timeout}s"


def lab(lab_id):
    if not re.fullmatch(r"[a-z0-9-]+", lab_id) or not (LABS / lab_id / "lab.json").is_file():
        return None
    return json.loads((LABS / lab_id / "lab.json").read_text())


def mock_labs():
    return sorted(d.name for d in LABS.iterdir() if (d / "lab.json").is_file() and json.loads((d / "lab.json").read_text()).get("mock"))


def active():
    return ACTIVE.read_text().strip() if ACTIVE.exists() else None


def empty(folder):
    folder.mkdir(parents=True, exist_ok=True)
    for child in folder.iterdir():
        shutil.rmtree(child) if child.is_dir() and not child.is_symlink() else child.unlink()


def reset_aws():
    urllib.request.urlopen(urllib.request.Request(f"{MOTO}/moto-api/reset", method="POST"), timeout=10)


def lab_env(lab_id, level, state):
    return {"LAB_DIR": str(LABS / lab_id), "LEVEL_DIR": str(LABS / lab_id / level), "LEVEL": level, "LAB_STATE": str(state)}


def prepare(lab_id, level, folder, state):
    state.mkdir(parents=True, exist_ok=True)
    for files in (LABS / lab_id / "files", LABS / lab_id / level / "files"):
        if files.is_dir():
            shutil.copytree(files, folder, dirs_exist_ok=True)
    setup = next((s for s in (LABS / lab_id / level / "setup.sh", LABS / lab_id / "setup.sh") if s.is_file()), None)
    return run(setup, folder, lab_env(lab_id, level, state), 600) if setup else (True, "")


def start(lab_id, level):
    reset_aws()
    empty(WORK)
    empty(EXAM)
    shutil.rmtree(STATE, ignore_errors=True)
    ok, output = prepare(lab_id, level, WORK, STATE)
    ACTIVE.write_text(f"{lab_id}:{level}" if ok else "")
    return {"ok": ok, "output": output, "active": active()}


def start_exam():
    reset_aws()
    empty(WORK)
    empty(EXAM)
    shutil.rmtree(STATE, ignore_errors=True)
    for lab_id in mock_labs():
        ok, output = prepare(lab_id, "exam", EXAM / lab_id, STATE / lab_id)
        if not ok:
            ACTIVE.write_text("")
            return {"ok": False, "output": f"{lab_id}: {output}", "active": None}
    ACTIVE.write_text("exam")
    return {"ok": True, "output": "", "active": "exam", "labs": mock_labs()}


def grade(lab_id, level, folder, state):
    meta = lab(lab_id)
    with tempfile.TemporaryDirectory() as tmp:
        results = []
        for task in meta["levels"][level]["tasks"]:
            ok, output = run(LABS / lab_id / level / "checks" / f"{task['id']}.sh", folder,
                             {**lab_env(lab_id, level, state), "CHECK_TMP": tmp, "LIB": str(LABS / "lib.sh")}, 180)
            results.append({"id": task["id"], "ok": ok, "output": output.strip()})
    return results


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
        force = self.path.endswith("?force=1")
        path = self.path.removesuffix("?force=1")
        if path == "/exam/start":
            return self.reply(200, start_exam())
        if path == "/exam/check":
            if active() != "exam":
                return self.reply(409, {"error": "The mock exam is not running."})
            return self.reply(200, {"labs": {i: grade(i, "exam", EXAM / i, STATE / i) for i in mock_labs()}})
        m = re.fullmatch(r"/labs/([^/]+)/([a-z]+)/(start|check)", path)
        meta = m and lab(m.group(1))
        if not meta or m.group(2) not in meta["levels"]:
            return self.reply(404, {"error": "unknown lab or level"})
        lab_id, level, action = m.groups()
        if action == "start":
            if active() == "exam" and not force:
                return self.reply(409, {"error": "A mock exam is running. Starting a lab ends it."})
            return self.reply(200, start(lab_id, level))
        if active() != f"{lab_id}:{level}":
            return self.reply(409, {"error": "This lab is not running. Start it first."})
        self.reply(200, {"results": grade(lab_id, level, WORK, STATE)})


if __name__ == "__main__":
    ThreadingHTTPServer(("0.0.0.0", 7000), Handler).serve_forever()
