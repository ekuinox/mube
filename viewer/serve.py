#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.10"
# dependencies = []
# ///
"""
Render the smart-lock parts to STL, serve the web viewer, and expose it through a
Cloudflare quick tunnel (no account needed).

Run it inside the Nix dev shell so `openscad`, `cloudflared`, and `uv` are on PATH:

    nix develop
    uv run --script viewer/serve.py        # or just: ./viewer/serve.py

`uv` provisions a consistent Python (no system python3 needed). openscad and
cloudflared come from the dev shell. Ctrl-C stops the server and the tunnel.
STL files land in build/ and are git-ignored — never committed.
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

ROOT = Path(__file__).resolve().parent.parent
BUILD = ROOT / "build"
SCAD = ROOT / "scad" / "smartlock.scad"
VIEWER_HTML = ROOT / "viewer" / "index.html"
PORT = int(os.environ.get("PORT", "8765"))
PARTS = ["body", "socket", "tray", "assembly", "asm_body", "asm_socket", "asm_tray"]
URL_RE = re.compile(r"https://[a-z0-9-]+\.trycloudflare\.com")


def require(tool: str) -> str:
    path = shutil.which(tool)
    if not path:
        sys.exit(f"{tool} not found on PATH — run inside `nix develop` first.")
    return path


def render_parts() -> None:
    require("openscad")
    BUILD.mkdir(exist_ok=True)
    for part in PARTS:
        out = BUILD / f"{part}.stl"
        print(f"rendering {part} -> {out.relative_to(ROOT)}")
        proc = subprocess.run(
            ["openscad", "-D", f'part="{part}"', "-o", str(out), str(SCAD)],
            capture_output=True,
            text=True,
        )
        if proc.returncode != 0:
            sys.stderr.write(proc.stderr)
            sys.exit(f"openscad failed rendering {part}")


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
    render_parts()
    shutil.copy(VIEWER_HTML, BUILD / "index.html")

    httpd = start_server()
    tunnel, url = start_tunnel()

    print("\n" + "=" * 60)
    print(f"  Open in your browser:  {url}")
    print("=" * 60 + "\n  Ctrl-C to stop.\n")

    stop = threading.Event()
    signal.signal(signal.SIGINT, lambda *_: stop.set())
    signal.signal(signal.SIGTERM, lambda *_: stop.set())
    stop.wait()

    print("\nstopping…")
    tunnel.terminate()
    httpd.shutdown()


if __name__ == "__main__":
    main()
