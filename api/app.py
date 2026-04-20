import subprocess
import tempfile
import os
import uuid
import time
import hashlib
from collections import defaultdict
from flask import Flask, request, jsonify, g
from functools import wraps

app = Flask(__name__)

API_KEY     = os.environ.get("HERCULES_API_KEY", "")
HERCULES_DIR   = os.environ.get("HERCULES_DIR", os.path.join(os.path.dirname(__file__), ".."))
HERCULES_SCRIPT = os.path.join(HERCULES_DIR, "hercules.lua")
MAX_CODE_SIZE  = int(os.environ.get("MAX_CODE_SIZE", 500_000))   # 500 KB
TIMEOUT_SECS   = int(os.environ.get("OBFUSCATE_TIMEOUT", 45))

# Simple in-memory rate limiter: max 10 req / 60s per IP
_rate_data: dict = defaultdict(list)
RATE_LIMIT  = int(os.environ.get("RATE_LIMIT", 10))
RATE_WINDOW = int(os.environ.get("RATE_WINDOW", 60))

def _rate_limit_check(ip: str) -> bool:
    now = time.time()
    window_start = now - RATE_WINDOW
    hits = _rate_data[ip] = [t for t in _rate_data[ip] if t > window_start]
    if len(hits) >= RATE_LIMIT:
        return False
    _rate_data[ip].append(now)
    return True

def require_api_key(f):
    @wraps(f)
    def decorated(*args, **kwargs):
        if API_KEY:
            key = (request.headers.get("X-API-Key") or
                   request.headers.get("Authorization", "").removeprefix("Bearer ") or
                   request.args.get("api_key", ""))
            if not key or not hmac_compare(key, API_KEY):
                return jsonify({"error": "Unauthorized"}), 401
        return f(*args, **kwargs)
    return decorated

def hmac_compare(a: str, b: str) -> bool:
    """Constant-time comparison to prevent timing attacks."""
    import hmac as _hmac
    return _hmac.compare_digest(a.encode(), b.encode())

VALID_FLAGS = {
    "control_flow":      "-cf",
    "string_encoding":   "-se",
    "variable_renaming": "-vr",
    "garbage_code":      "-gci",
    "opaque_predicates": "-opi",
    "bytecode_encoding": "-be",
    "string_to_expr":    "-st",
    "virtual_machine":   "-vm",
    "wrap_in_func":      "-wif",
    "func_inlining":     "-fi",
    "dynamic_code":      "-dc",
    "compressor":        "-c",
    "antitamper":        "-at",
}

@app.route("/health", methods=["GET"])
def health():
    return jsonify({"status": "ok", "version": "1.6"}), 200

@app.route("/obfuscate", methods=["POST"])
@require_api_key
def obfuscate():
    """
    POST /obfuscate
    Headers:
      X-API-Key: <your key>
      Content-Type: application/json
    Body:
    {
      "code": "<lua source>",
      "options": {
        "preset": "min" | "mid" | "max",
        "virtual_machine": true,
        "variable_renaming": true,
        ...
      }
    }
    """
    # Rate limit
    ip = request.headers.get("X-Forwarded-For", request.remote_addr or "unknown").split(",")[0].strip()
    if not _rate_limit_check(ip):
        return jsonify({"error": "Rate limit exceeded. Try again later."}), 429

    data = request.get_json(force=True, silent=True)
    if not data or "code" not in data:
        return jsonify({"error": "Missing 'code' field"}), 400

    source_code = data.get("code", "")
    if not isinstance(source_code, str) or not source_code.strip():
        return jsonify({"error": "'code' must be a non-empty string"}), 400
    if len(source_code.encode("utf-8")) > MAX_CODE_SIZE:
        return jsonify({"error": f"Code too large (max {MAX_CODE_SIZE//1024}KB)"}), 413

    options = data.get("options", {})
    if not isinstance(options, dict):
        options = {}

    # Build CLI flags
    flags = []
    preset = options.get("preset")
    if preset in ("min", "mid", "max"):
        flags.append(f"--{preset}")
    else:
        for opt_name, flag in VALID_FLAGS.items():
            if options.get(opt_name) is True:
                flags.append(flag)

    # Sanity check flag (optional)
    if options.get("sanity_check") is True:
        flags.append("--sanity")

    tmp_dir     = tempfile.mkdtemp(prefix="hercules_")
    uid         = uuid.uuid4().hex
    input_path  = os.path.join(tmp_dir, f"src_{uid}.lua")
    output_path = os.path.join(tmp_dir, f"src_{uid}_obfuscated.lua")

    try:
        with open(input_path, "w", encoding="utf-8") as f:
            f.write(source_code)

        cmd = ["lua5.1", HERCULES_SCRIPT, input_path] + flags
        proc = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=TIMEOUT_SECS,
            cwd=HERCULES_DIR,
            env={**os.environ, "LUA_PATH": f"{HERCULES_DIR}/?.lua;;"},
        )

        if proc.returncode != 0:
            stderr = (proc.stderr or proc.stdout or "unknown error")[:2000]
            return jsonify({"error": "Obfuscation failed", "details": stderr}), 500

        if not os.path.exists(output_path):
            return jsonify({"error": "Obfuscator produced no output file"}), 500

        with open(output_path, "r", encoding="utf-8") as f:
            result = f.read()

        if not result.strip():
            return jsonify({"error": "Obfuscator returned empty output"}), 500

        return jsonify({
            "obfuscated": result,
            "original_size": len(source_code),
            "obfuscated_size": len(result),
        }), 200

    except subprocess.TimeoutExpired:
        return jsonify({"error": f"Timed out after {TIMEOUT_SECS}s"}), 504
    except Exception as exc:
        app.logger.exception("Unexpected error in /obfuscate")
        return jsonify({"error": "Internal server error"}), 500
    finally:
        for path in (input_path, output_path):
            try:
                if os.path.exists(path):
                    os.remove(path)
            except OSError:
                pass
        try:
            os.rmdir(tmp_dir)
        except OSError:
            pass

@app.errorhandler(404)
def not_found(_): return jsonify({"error": "Not found"}), 404

@app.errorhandler(405)
def method_not_allowed(_): return jsonify({"error": "Method not allowed"}), 405

if __name__ == "__main__":
    port = int(os.environ.get("PORT", 5000))
    app.run(host="0.0.0.0", port=port, debug=False)
