#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.10"
# dependencies = []
# ///
"""
Generate the breadboard wiring diagrams (all presets) to SVG, serve the web
viewer, and expose it through a Cloudflare quick tunnel (no account needed).

Run it inside the Nix dev shell so `bun` and `cloudflared` are on PATH
(the convenience wrapper `./circuit/breadboard.sh` re-enters the shell for you):

    nix develop
    uv run --script circuit/breadboard-serve.py   # or just: ./circuit/breadboard.sh

`uv` provisions a consistent Python (no system python3 needed). bun renders the
SVGs via circuit/breadboard-auto.ts; cloudflared comes from the dev shell.
Ctrl-C stops the server and the tunnel. SVGs land in build/ and are git-ignored.
"""
from __future__ import annotations

import functools
import http.server
import os
import re
import shutil
import signal
import socketserver
import subprocess
import sys
import threading
from pathlib import Path

CIRCUIT = Path(__file__).resolve().parent
ROOT = CIRCUIT.parent
BUILD = ROOT / "build"
VIEWER_HTML = CIRCUIT / "breadboard-viewer.html"
PORT = int(os.environ.get("PORT", "8766"))  # viewer/serve.py は 8765 を使う
PRESETS = ["SERVO_DRIVE", "LED_BUTTON", "FULL"]
URL_RE = re.compile(r"https://[a-z0-9-]+\.trycloudflare\.com")


def require(tool: str) -> str:
    path = shutil.which(tool)
    if not path:
        sys.exit(f"{tool} not found on PATH — run inside `nix develop` first.")
    return path


def render_diagrams() -> None:
    require("bun")
    BUILD.mkdir(exist_ok=True)
    for preset in PRESETS:
        out = BUILD / f"breadboard-{preset.lower()}.svg"
        print(f"rendering {preset} -> {out.relative_to(ROOT)}")
        proc = subprocess.run(
            ["bun", "breadboard-auto.ts", preset],
            cwd=str(CIRCUIT),
            capture_output=True,
            text=True,
        )
        if proc.returncode != 0:
            sys.stderr.write(proc.stdout)
            sys.stderr.write(proc.stderr)
            sys.exit(f"bun failed rendering {preset}")
        if not out.exists():
            sys.exit(f"expected {out} was not produced")

    # ユニバーサル基板（実装用）配線図も生成
    print("rendering PERFBOARD -> build/perfboard.svg")
    proc = subprocess.run(
        ["bun", "perfboard.ts"],
        cwd=str(CIRCUIT), capture_output=True, text=True,
    )
    if proc.returncode != 0:
        sys.stderr.write(proc.stdout)
        sys.stderr.write(proc.stderr)
        sys.exit("bun failed rendering perfboard")
    if not (BUILD / "perfboard.svg").exists():
        sys.exit("expected build/perfboard.svg was not produced")


def start_server() -> socketserver.TCPServer:
    handler = functools.partial(
        http.server.SimpleHTTPRequestHandler, directory=str(BUILD)
    )
    httpd = socketserver.ThreadingTCPServer(("127.0.0.1", PORT), handler)
    httpd.daemon_threads = True
    threading.Thread(target=httpd.serve_forever, daemon=True).start()
    print(f"serving {BUILD.relative_to(ROOT)}/ at http://127.0.0.1:{PORT}")
    return httpd


def start_tunnel() -> tuple[subprocess.Popen, str]:
    """Spawn cloudflared, return (process, public_url). Drains stderr in a thread."""
    require("cloudflared")
    proc = subprocess.Popen(
        ["cloudflared", "tunnel", "--no-autoupdate", "--url", f"http://127.0.0.1:{PORT}"],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.PIPE,
        text=True,
    )
    found: dict[str, str] = {}
    ready = threading.Event()

    def drain() -> None:
        for line in proc.stderr:  # type: ignore[union-attr]
            if "url" not in found:
                m = URL_RE.search(line)
                if m:
                    found["url"] = m.group(0)
                    ready.set()
        ready.set()  # stream closed without a URL -> unblock the waiter

    threading.Thread(target=drain, daemon=True).start()
    if not ready.wait(timeout=60) or "url" not in found:
        proc.terminate()
        sys.exit("cloudflared did not produce a tunnel URL within 60s")
    return proc, found["url"]


def main() -> None:
    sys.stdout.reconfigure(line_buffering=True)  # show the URL immediately when piped
    render_diagrams()
    shutil.copy(VIEWER_HTML, BUILD / "breadboard.html")

    httpd = start_server()

    if os.environ.get("NO_TUNNEL"):
        url = f"http://127.0.0.1:{PORT}"
        tunnel = None
    else:
        tunnel, base = start_tunnel()
        url = base
    page = f"{url}/breadboard.html"

    print("\n" + "=" * 60)
    print(f"  Open in your browser:  {page}")
    print("=" * 60 + "\n  Ctrl-C to stop.\n")

    stop = threading.Event()
    signal.signal(signal.SIGINT, lambda *_: stop.set())
    signal.signal(signal.SIGTERM, lambda *_: stop.set())
    stop.wait()

    print("\nstopping…")
    if tunnel:
        tunnel.terminate()
    httpd.shutdown()


if __name__ == "__main__":
    main()
