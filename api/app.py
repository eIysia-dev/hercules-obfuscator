import subprocess
import tempfile
import os
import uuid
import time
from collections import defaultdict
from flask import Flask, request, jsonify
from functools import wraps

app = Flask(__name__)

API_KEY = os.environ.get("HERCULES_API_KEY", "")
BASE_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))

HERCULES_DIR = os.path.join(BASE_DIR, "src")
HERCULES_SCRIPT = os.path.join(HERCULES_DIR, "hercules.lua")

MAX_CODE_SIZE = int(os.environ.get("MAX_CODE_SIZE", 500_000))
TIMEOUT_SECS = int(os.environ.get("OBFUSCATE_TIMEOUT", 45))

_rate_data = defaultdict(list)
RATE_LIMIT = 10
RATE_WINDOW = 60


def rate_limit(ip: str) -> bool:
    now = time.time()
    window = now - RATE_WINDOW
    _rate_data[ip] = [t for t in _rate_data[ip] if t > window]

    if len(_rate_data[ip]) >= RATE_LIMIT:
        return False

    _rate_data[ip].append(now)
    return True


def require_api_key(f):
    @wraps(f)
    def wrapper(*args, **kwargs):
        if API_KEY:
            key = request.headers.get("X-API-Key", "")
            if key != API_KEY:
                return jsonify({"error": "Unauthorized"}), 401
        return f(*args, **kwargs)
    return wrapper


@app.route("/health", methods=["GET"])
def health():
    return jsonify({"status": "ok"})


@app.route("/obfuscate", methods=["POST"])
@require_api_key
def obfuscate():
    ip = request.remote_addr or "unknown"
    if not rate_limit(ip):
        return jsonify({"error": "Rate limit exceeded"}), 429

    data = request.get_json(silent=True) or {}
    code = data.get("code", "")

    if not isinstance(code, str) or not code.strip():
        return jsonify({"error": "Missing code"}), 400

    if len(code.encode()) > MAX_CODE_SIZE:
        return jsonify({"error": "Code too large"}), 413

    options = data.get("options", {}) or {}

    flags = []
    preset = options.get("preset")
    if preset in ("min", "mid", "max"):
        flags.append(f"--{preset}")

    tmp_dir = tempfile.mkdtemp()
    uid = uuid.uuid4().hex
    input_path = os.path.join(tmp_dir, f"{uid}.lua")

    try:
        with open(input_path, "w", encoding="utf-8") as f:
            f.write(code)

        cmd = [
            "lua5.1",
            HERCULES_SCRIPT,
            input_path,
            "--api"   # 🔥 FORCE API MODE ALWAYS
        ] + flags

        proc = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=TIMEOUT_SECS,
            cwd=HERCULES_DIR,
            env={**os.environ, "LUA_PATH": f"{HERCULES_DIR}/?.lua;;"},
        )

        stdout = (proc.stdout or "").strip()
        stderr = (proc.stderr or "").strip()

        if proc.returncode != 0:
            return jsonify({
                "error": "Obfuscation failed",
                "details": stderr[:2000] or stdout[:2000]
            }), 500

        # 🔥 HARD VALIDATION: ensure it's actually Lua
        if not stdout or "error" in stdout.lower():
            return jsonify({
                "error": "Invalid obfuscator output",
                "raw": stdout[:2000]
            }), 500

        return jsonify({
            "obfuscated_code": stdout,   # ✅ CLEAN FIELD NAME
            "original_size": len(code),
            "obfuscated_size": len(stdout),
            "success": True
        })

    except subprocess.TimeoutExpired:
        return jsonify({"error": "Timeout"}), 504

    except Exception as e:
        return jsonify({"error": str(e)}), 500

    finally:
        try:
            os.remove(input_path)
            os.rmdir(tmp_dir)
        except:
            pass

if __name__ == "__main__":
    port = int(os.environ.get("PORT", 5000))
    app.run(host="0.0.0.0", port=port)
