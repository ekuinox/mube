#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.10"
# dependencies = []
# ///
"""
ブレッドボード配線図（全プリセット）を SVG に生成し、ブラウザビューアを配信し、
Cloudflare quick tunnel（アカウント不要）で公開するスクリプト。

`bun` と `cloudflared` に PATH を通すため Nix dev シェルの中で実行する
（ラッパ `./circuit/breadboard.sh` が自動でシェルに再突入してくれる）:

    nix develop
    uv run --script circuit/breadboard-serve.py   # もしくは: ./circuit/breadboard.sh

`uv` が一貫した Python を用意する（システムの python3 は不要）。SVG は bun が
circuit/breadboard-auto.ts で描画し、cloudflared は dev シェルから来る。
Ctrl-C でサーバとトンネルを停止。SVG は build/ に出力され git-ignore 済み。
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

CIRCUIT = Path(__file__).resolve().parent      # circuit/ ディレクトリ
ROOT = CIRCUIT.parent                           # リポジトリルート
BUILD = ROOT / "build"                          # 生成物の出力先（git-ignore）
VIEWER_HTML = CIRCUIT / "breadboard-viewer.html"
PORT = int(os.environ.get("PORT", "8766"))      # viewer/serve.py は 8765 を使うので衝突回避
PRESETS = ["SERVO_DRIVE", "LED_BUTTON", "FULL"]  # 生成するプリセット（breadboard-auto.ts のキー）
URL_RE = re.compile(r"https://[a-z0-9-]+\.trycloudflare\.com")  # トンネル公開 URL の抽出用


def require(tool: str) -> str:
    """外部コマンドが PATH にあるか確認し、無ければ dev シェル誘導で終了する。"""
    path = shutil.which(tool)
    if not path:
        sys.exit(f"{tool} not found on PATH — run inside `nix develop` first.")
    return path


def render_diagrams() -> None:
    """全プリセットを breadboard-auto.ts で描画し build/breadboard-<preset>.svg を作る。"""
    require("bun")
    BUILD.mkdir(exist_ok=True)
    for preset in PRESETS:
        # 出力名は auto.ts 側と揃えて小文字化（例: SERVO_DRIVE -> breadboard-servo_drive.svg）
        out = BUILD / f"breadboard-{preset.lower()}.svg"
        print(f"rendering {preset} -> {out.relative_to(ROOT)}")
        proc = subprocess.run(
            ["bun", "breadboard-auto.ts", preset],
            cwd=str(CIRCUIT),
            capture_output=True,
            text=True,
        )
        # bun 失敗時はその出力をそのまま見せて中断（原因を隠さない）
        if proc.returncode != 0:
            sys.stderr.write(proc.stdout)
            sys.stderr.write(proc.stderr)
            sys.exit(f"bun failed rendering {preset}")
        # 戻り値 0 でも SVG が出ていなければ異常として扱う
        if not out.exists():
            sys.exit(f"expected {out} was not produced")


def start_server() -> socketserver.TCPServer:
    """build/ を配信する HTTP サーバをバックグラウンドスレッドで起動する。"""
    # 配信ルートを build/ に固定（SVG と breadboard.html が同じ階層に並ぶ）
    handler = functools.partial(
        http.server.SimpleHTTPRequestHandler, directory=str(BUILD)
    )
    httpd = socketserver.ThreadingTCPServer(("127.0.0.1", PORT), handler)
    httpd.daemon_threads = True  # メインが終わったらリクエスト処理スレッドも道連れに
    threading.Thread(target=httpd.serve_forever, daemon=True).start()
    print(f"serving {BUILD.relative_to(ROOT)}/ at http://127.0.0.1:{PORT}")
    return httpd


def start_tunnel() -> tuple[subprocess.Popen, str]:
    """cloudflared を起動し (プロセス, 公開URL) を返す。stderr は別スレッドで読み続ける。"""
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
        # cloudflared は起動ログを stderr に流す。URL 行を見つけたら待ち手を起こす。
        for line in proc.stderr:  # type: ignore[union-attr]
            if "url" not in found:
                m = URL_RE.search(line)
                if m:
                    found["url"] = m.group(0)
                    ready.set()
        ready.set()  # URL を出さないままストリームが閉じても待ち手を解放する

    threading.Thread(target=drain, daemon=True).start()
    # 60 秒で URL が取れなければ諦めてプロセスを畳む
    if not ready.wait(timeout=60) or "url" not in found:
        proc.terminate()
        sys.exit("cloudflared did not produce a tunnel URL within 60s")
    return proc, found["url"]


def main() -> None:
    sys.stdout.reconfigure(line_buffering=True)  # パイプ経由でも URL を即表示させる
    render_diagrams()
    # ビューア HTML を build/ にコピーし、SVG と同一オリジンで配信できるようにする
    shutil.copy(VIEWER_HTML, BUILD / "breadboard.html")

    httpd = start_server()

    # NO_TUNNEL=1 のときはトンネルを張らずローカル配信のみ
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

    # SIGINT / SIGTERM を受けるまでブロックし、受けたら後片付けへ
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
