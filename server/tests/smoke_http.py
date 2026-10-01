"""Exercise the actual WSGI server over HTTP; no provider API calls or real credentials."""
import json
import os
import socket
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.request
from pathlib import Path

server = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(server))
from app import Store

with tempfile.TemporaryDirectory() as temp:
    database = str(Path(temp) / "test.sqlite")
    store = Store(database)
    token = store.issue("http-test")
    with socket.socket() as probe:
        probe.bind(("127.0.0.1", 0))
        port = probe.getsockname()[1]
    environment = dict(os.environ, COWRITTEN_DATABASE=database, PYTHONPATH=str(server) + os.pathsep + str(server / "tests"))
    process = subprocess.Popen([str(Path(sys.executable).with_name("gunicorn")), "--bind", f"127.0.0.1:{port}",
        "--workers", "2", "--threads", "2", "--access-logfile", "/dev/null", "http_fixture:create_app()"], env=environment,
        stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
    try:
        for _ in range(100):
            try:
                with urllib.request.urlopen(f"http://127.0.0.1:{port}/health", timeout=1) as response:
                    assert json.load(response) == {"status": "ok"}
                break
            except OSError:
                if process.poll() is not None:
                    raise RuntimeError(process.stderr.read().decode())
                time.sleep(0.05)
        else:
            raise RuntimeError("HTTP service did not start")
        url = f"http://127.0.0.1:{port}/v1/analyze"
        body = json.dumps({"text": "We wrote a test passage."}).encode()
        request = urllib.request.Request(url, data=body, headers={"Content-Type": "application/json"})
        try:
            urllib.request.urlopen(request, timeout=3)
            raise AssertionError("Unauthenticated request accepted")
        except urllib.error.HTTPError as error:
            assert error.code == 401
            error.close()
        request.add_header("Authorization", "Bearer " + token)
        with urllib.request.urlopen(request, timeout=3) as response:
            assert response.headers["Cache-Control"] == "no-store"
            assert json.load(response)["summary"] == "A fixture result."
        store.revoke("http-test")
        try:
            urllib.request.urlopen(request, timeout=3)
            raise AssertionError("Revoked token accepted")
        except urllib.error.HTTPError as error:
            assert error.code == 401
            error.close()
        print("HTTP smoke passed: two workers, auth, structured analysis, no-store, revocation")
    finally:
        process.terminate()
        process.communicate(timeout=10)
