#!/usr/bin/env bash
# Render all parts, assemble the viewer, serve it locally, and expose it through
# a Cloudflare quick tunnel (no account needed). Ctrl-C stops everything.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PORT="${PORT:-8765}"
command -v nix >/dev/null 2>&1 || export PATH="/nix/var/nix/profiles/default/bin:$PATH"
cd "$ROOT"

# 1. Render STLs (body/lid/socket via build.sh, plus the assembly preview).
./build.sh
nix shell nixpkgs#openscad -c openscad -D 'part="assembly"' -o build/assembly.stl scad/smartlock.scad

# 2. Drop the viewer next to the STLs so they share an origin.
cp viewer/index.html build/index.html

# 3. Static server in the background.
echo "Serving build/ at http://localhost:$PORT"
nix shell nixpkgs#python3 -c python3 -m http.server "$PORT" --directory build &
SERVER_PID=$!
trap 'kill $SERVER_PID 2>/dev/null' EXIT

# 4. Public quick tunnel (prints a https://*.trycloudflare.com URL).
nix shell nixpkgs#cloudflared -c cloudflared tunnel --url "http://localhost:$PORT"
