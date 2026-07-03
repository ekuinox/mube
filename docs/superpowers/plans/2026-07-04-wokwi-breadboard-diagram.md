# Wokwi 配線見本図生成 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `circuit/netlist.py` の netlist から Wokwi の diagram.json（全部品・全 net の配線見本）と CLI シミュレーション用の簡略版を生成し、wokwi-cli を nix devShell に追加する。

**Architecture:** 新スクリプト `circuit/wokwi.py` が `netlist.py` の `PARTS`/`NETS`/`PART_META` を import して `build/wokwi/` に生成する。Wokwi に無いディスクリート部品（Q1/C1/C2/D2）はカスタムチップ（chip.json + 空の chip.c）で表現し、net は簡略化しない。wokwi-cli 用にはカスタムチップを除いた `sim/` 版を併産する（CLI はカスタムチップに wasm を要求するため）。

**Tech Stack:** Python 3.10+（PEP 723 uv スクリプト・依存ゼロ）、Nix flake、wokwi-cli v0.26.1（GitHub リリースのスタティックバイナリ）。

## Global Constraints

- `uv` / `nix` は非対話 PATH に無い。テスト実行は `nix develop -c ./test/wokwi_test.py` の形（CLAUDE.md 準拠）。
- `build/` は派生物で非コミット（.gitignore 済み）。生成物をコミットしない。
- `WOKWI_CLI_TOKEN` は秘密。値を会話・コミット・ファイルに載せない。環境変数でのみ渡す。
- 既存の `netlist.py` の責務（ERC / from-to / bom）は変更しない。
- 事前確認済みの事実: Pico W の部品タイプは `wokwi-pi-pico-w`、ピン名は `GP15` / `GND.1` / `VBUS` 形式。接続は `["pico:GP15", "r1:1", "green", []]` 形式。wokwi-cli v0.26.1 の nix-prefetch-url ハッシュは arm64 = `1rxi05ci5jj0q1kdh0nx9lr0633vy7lpzcglydmsqkxrdk7w0p90`、x64 = `04g873ypgdpxpkzr3vygwg1sd5asp0g79dvsqhr7bbxb1caninbj`。

---

### Task 1: `circuit/wokwi.py` 生成スクリプトとテスト

**Files:**
- Create: `circuit/wokwi.py`
- Test: `test/wokwi_test.py`

**Interfaces:**
- Consumes: `circuit/netlist.py` の `PARTS`, `NETS`, `PART_META`, `ROOT`（既存・変更しない）
- Produces: 実行すると `build/wokwi/diagram.json`, `build/wokwi/chips/*.chip.json`, `build/wokwi/chips/*.chip.c`, `build/wokwi/sim/diagram.json`, `build/wokwi/sim/wokwi.toml`, `build/wokwi/notes.md` を出力。モジュールとしては `wokwi_endpoints(ref, pin) -> list[str]`, `gen_diagram(nets, sim=False) -> tuple[dict, list[str]]`, `PIN_TABLE: dict[str, set[str]]`, `CHIPS: dict[str, list[str]]` を公開（Task 2 以降は使わないがテストが使う）。

- [ ] **Step 1: 失敗するテストを書く**

`test/wokwi_test.py` を `test/netlist_test.py` と同じ自前ランナー形式で作成:

```python
#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.10"
# dependencies = []
# ///
"""Tests for circuit/wokwi.py. Run: ./test/wokwi_test.py"""
import sys, json, pathlib, subprocess

ROOT = pathlib.Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "circuit"))
import netlist as n
import wokwi as w


def pairs_of(diagram):
    return {frozenset((c[0], c[1])) for c in diagram["connections"]}


def test_endpoint_mapping_pico():
    assert w.wokwi_endpoints("U1", "GP15") == ["pico:GP15"]
    assert w.wokwi_endpoints("U1", "GND") == ["pico:GND.1"]
    assert w.wokwi_endpoints("U1", "VBUS") == ["pico:VBUS"]


def test_endpoint_mapping_servo_and_button():
    assert w.wokwi_endpoints("M1", "SIG") == ["servo:PWM"]
    assert w.wokwi_endpoints("M1", "V+") == ["servo:V+"]
    assert w.wokwi_endpoints("SW1", "1") == ["btn:1.l"]


def test_endpoint_mapping_led_split():
    assert w.wokwi_endpoints("D1", "R") == ["led_r:A"]
    assert w.wokwi_endpoints("D1", "G") == ["led_g:A"]
    assert w.wokwi_endpoints("D1", "K") == ["led_r:C", "led_g:C"]


def test_endpoint_mapping_custom_chips():
    assert w.wokwi_endpoints("Q1", "G") == ["q1:G"]
    assert w.wokwi_endpoints("C1", "+") == ["c1:+"]
    assert w.wokwi_endpoints("D2", "K") == ["d2:K"]


def test_unmapped_ref_returns_empty():
    assert w.wokwi_endpoints("X9", "1") == []


def test_full_diagram_covers_all_nets():
    diagram, warnings = w.gen_diagram(n.NETS)
    assert warnings == [], warnings
    got = pairs_of(diagram)
    for name, eps in n.NETS.items():
        flat = [e for ref, pin in eps for e in w.wokwi_endpoints(ref, pin)]
        for a, b in zip(flat, flat[1:]):
            assert frozenset((a, b)) in got, f"{name}: {a} -> {b} missing"


def test_full_diagram_endpoints_are_valid_pins():
    diagram, _ = w.gen_diagram(n.NETS)
    ids = {p["id"] for p in diagram["parts"]}
    for c in diagram["connections"]:
        for ep in (c[0], c[1]):
            pid, pin = ep.split(":", 1)
            assert pid in ids, ep
            assert pin in w.PIN_TABLE[pid], ep


def test_sim_diagram_has_no_custom_chips():
    diagram, _ = w.gen_diagram(n.NETS, sim=True)
    assert all(not p["type"].startswith("chip-") for p in diagram["parts"])


def test_sim_diagram_keeps_servo_powered():
    diagram, _ = w.gen_diagram(n.NETS, sim=True)
    got = pairs_of(diagram)
    assert frozenset(("servo:GND", "pico:GND.1")) in got
    assert frozenset(("servo:V+", "pico:VBUS")) in got or any(
        "servo:V+" in p for p in got), "servo V+ unconnected"


def test_unmapped_ref_warns_in_gen():
    nets = {"N1": [("U1", "GP15"), ("X9", "1")]}
    _, warnings = w.gen_diagram(nets)
    assert any("X9" in msg for msg in warnings), warnings


def test_main_generates_files():
    out = subprocess.run([str(ROOT / "circuit" / "wokwi.py")],
                         capture_output=True, text=True)
    assert out.returncode == 0, out.stderr
    base = ROOT / "build" / "wokwi"
    d = json.loads((base / "diagram.json").read_text())
    assert d["version"] == 1
    json.loads((base / "sim" / "diagram.json").read_text())
    for chip in w.CHIPS:
        assert (base / "chips" / f"{chip}.chip.json").exists()
        assert (base / "chips" / f"{chip}.chip.c").exists()
    assert (base / "sim" / "wokwi.toml").exists()
    notes = (base / "notes.md").read_text()
    assert "IRLB3813PBF" in notes


TESTS = [
    test_endpoint_mapping_pico,
    test_endpoint_mapping_servo_and_button,
    test_endpoint_mapping_led_split,
    test_endpoint_mapping_custom_chips,
    test_unmapped_ref_returns_empty,
    test_full_diagram_covers_all_nets,
    test_full_diagram_endpoints_are_valid_pins,
    test_sim_diagram_has_no_custom_chips,
    test_sim_diagram_keeps_servo_powered,
    test_unmapped_ref_warns_in_gen,
    test_main_generates_files,
]


def main():
    failed = 0
    for t in TESTS:
        try:
            t()
            print(f"PASS {t.__name__}")
        except AssertionError as e:
            failed += 1
            print(f"FAIL {t.__name__}: {e}")
    if failed:
        print(f"{failed} test(s) failed")
        sys.exit(1)
    print("all tests passed")


if __name__ == "__main__":
    main()
```

実行可能にする: `chmod +x test/wokwi_test.py`

- [ ] **Step 2: テストが落ちることを確認**

Run: `nix develop -c ./test/wokwi_test.py`
Expected: `ModuleNotFoundError: No module named 'wokwi'` で失敗

- [ ] **Step 3: `circuit/wokwi.py` を実装**

```python
#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.10"
# dependencies = []
# ///
"""
Wokwi wiring-reference generator: reads circuit/netlist.py and emits
build/wokwi/ artifacts for viewing on wokwi.com (full diagram with custom
chips) and for wokwi-cli simulation (sim/ without custom chips, which the
CLI cannot load without compiled wasm).

    ./circuit/wokwi.py          # inside nix develop, or via uv

Outputs (all git-ignored under build/):
    build/wokwi/diagram.json        full wiring reference (paste into wokwi.com)
    build/wokwi/chips/*.chip.json   custom chip pin definitions
    build/wokwi/chips/*.chip.c      empty chip bodies (web editor compiles them)
    build/wokwi/sim/diagram.json    simplified, stock-parts-only diagram
    build/wokwi/sim/wokwi.toml      wokwi-cli project pointing at the firmware ELF
    build/wokwi/notes.md            custom-chip appearance notes + real-part table
"""
from __future__ import annotations
import json
import sys
import pathlib

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import netlist as nl

# ref -> (wokwi part type, diagram id, attrs). D1 is handled separately
# because one 2-color LED becomes two wokwi-led parts.
WOKWI_PARTS = {
    "U1": ("wokwi-pi-pico-w", "pico", {}),
    "M1": ("wokwi-servo", "servo", {}),
    "Rg": ("wokwi-resistor", "rg", {"value": "220"}),
    "Rgs": ("wokwi-resistor", "rgs", {"value": "10000"}),
    "Rled": ("wokwi-resistor", "rled", {"value": "330"}),
    "Rled2": ("wokwi-resistor", "rled2", {"value": "330"}),
    "SW1": ("wokwi-pushbutton", "btn", {"color": "blue"}),
    "Q1": ("chip-mosfet", "q1", {}),
    "C1": ("chip-cap-pol", "c1", {}),
    "C2": ("chip-cap", "c2", {}),
    "D2": ("chip-schottky", "d2", {}),
}
D1_PARTS = [("wokwi-led", "led_r", {"color": "red"}),
            ("wokwi-led", "led_g", {"color": "green"})]

# Custom chip name -> pins. Visual-only: chip.c bodies are empty.
CHIPS = {
    "mosfet": ["G", "D", "S"],
    "cap-pol": ["+", "-"],
    "cap": ["1", "2"],
    "schottky": ["A", "K"],
}

# Valid pins per diagram id, used by tests and kept next to the mapping so
# they change together.
PIN_TABLE = {
    "pico": {"VBUS", "VSYS", "3V3", "EN", "RUN"}
            | {f"GP{i}" for i in range(29)} | {f"GND.{i}" for i in range(1, 9)},
    "servo": {"GND", "V+", "PWM"},
    "rg": {"1", "2"}, "rgs": {"1", "2"}, "rled": {"1", "2"}, "rled2": {"1", "2"},
    "led_r": {"A", "C"}, "led_g": {"A", "C"},
    "btn": {"1.l", "1.r", "2.l", "2.r"},
    "q1": set(CHIPS["mosfet"]), "c1": set(CHIPS["cap-pol"]),
    "c2": set(CHIPS["cap"]), "d2": set(CHIPS["schottky"]),
}

# Fixed layout: Pico center, LEDs/button left, servo + MOSFET cluster right.
POSITIONS = {
    "pico": (100, 300), "servo": (40, 620), "q1": (200, 620), "d2": (120, 750),
    "c1": (300, 480), "c2": (300, 620), "rg": (220, 500), "rgs": (280, 560),
    "rled": (60, 140), "rled2": (140, 140), "led_r": (40, 20), "led_g": (120, 20),
    "btn": (240, 60),
}

NET_COLORS = {"+5V": "red", "GND": "black"}
PALETTE = ["green", "yellow", "orange", "purple", "cyan", "magenta", "blue", "gold"]

# In the sim diagram the MOSFET low-side switch disappears, which would leave
# the servo ground floating; bridge it straight to the Pico ground instead.
SIM_EXTRA = [["servo:GND", "pico:GND.1", "black", []]]


def wokwi_endpoints(ref, pin):
    """netlist (ref, pin) -> list of 'id:PIN' diagram endpoints ([] if unmapped)."""
    if ref == "U1":
        return [f"pico:{'GND.1' if pin == 'GND' else pin}"]
    if ref == "M1":
        return [f"servo:{'PWM' if pin == 'SIG' else pin}"]
    if ref == "D1":
        return {"R": ["led_r:A"], "G": ["led_g:A"],
                "K": ["led_r:C", "led_g:C"]}.get(pin, [])
    if ref == "SW1":
        return [f"btn:{pin}.l"]
    if ref in WOKWI_PARTS:
        return [f"{WOKWI_PARTS[ref][1]}:{pin}"]
    return []


def gen_diagram(nets, sim=False):
    """Build (diagram dict, warnings). sim=True drops custom-chip parts/nets."""
    warnings = []
    parts = []
    for ref, (ptype, pid, attrs) in WOKWI_PARTS.items():
        if sim and ptype.startswith("chip-"):
            continue
        top, left = POSITIONS[pid]
        part = {"type": ptype, "id": pid, "top": top, "left": left}
        if attrs:
            part["attrs"] = attrs
        parts.append(part)
    for ptype, pid, attrs in D1_PARTS:
        top, left = POSITIONS[pid]
        parts.append({"type": ptype, "id": pid, "top": top, "left": left,
                      "attrs": attrs})
    ids = {p["id"] for p in parts}

    connections = []
    palette = iter(PALETTE * 4)
    for name, eps in nets.items():
        color = NET_COLORS.get(name) or next(palette)
        flat = []
        for ref, pin in eps:
            mapped = wokwi_endpoints(ref, pin)
            if not mapped:
                warnings.append(f"no wokwi mapping for {ref}.{pin} (net {name})")
                continue
            flat.extend(e for e in mapped if e.split(":", 1)[0] in ids)
        for a, b in zip(flat, flat[1:]):
            connections.append([a, b, color, []])
    if sim:
        connections.extend(SIM_EXTRA)
    diagram = {"version": 1, "author": "smtlk (generated by circuit/wokwi.py)",
               "editor": "wokwi", "parts": parts, "connections": connections}
    return diagram, warnings


def gen_chip_files(out):
    for name, pins in CHIPS.items():
        (out / f"{name}.chip.json").write_text(json.dumps(
            {"name": name, "author": "smtlk", "pins": pins}, indent=2) + "\n")
        (out / f"{name}.chip.c").write_text(
            '// Visual-only part: no behavior. The Wokwi web editor requires a\n'
            '// chip.c to compile; an empty init is enough to place and wire it.\n'
            '#include "wokwi-api.h"\n'
            'void chip_init(void) {}\n')


def gen_notes(warnings):
    lines = [
        "# Wokwi 図の読みかた",
        "",
        "カスタムチップ (q1/c1/c2/d2) は Wokwi 上では汎用 IC ボディで描画される。",
        "実物との対応:",
        "",
        "| 図の id | Ref | 実部品 | 型番/値 |",
        "|---------|-----|--------|---------|",
    ]
    for pid, ref in [("q1", "Q1"), ("c1", "C1"), ("c2", "C2"), ("d2", "D2")]:
        name, value = nl.PART_META[ref]
        lines.append(f"| {pid} | {ref} | {name} | {value} |")
    lines += [
        "",
        "D1（2色LED 共通カソード）は wokwi-led 2個 (led_r / led_g) で表現している。",
        "実物は 1 部品で、K は共通ピン。",
        "",
        "## wokwi.com での見かた",
        "",
        "1. wokwi.com で Pico W の新規プロジェクトを作る",
        "2. diagram.json タブに build/wokwi/diagram.json を貼り付ける",
        "3. F1 → 'Create Custom Chip' で mosfet / cap-pol / cap / schottky を作り、",
        "   chips/ 以下の同名 .chip.json / .chip.c を貼り付ける",
        "",
        "## sim/ について",
        "",
        "wokwi-cli はカスタムチップに wasm を要求するため、sim/diagram.json は",
        "カスタムチップ抜きの簡略版（サーボGNDはPicoに直結）。実配線は",
        "build/from-to.md と diagram.json が正。",
    ]
    if warnings:
        lines += ["", "## 未対応部品の警告", ""]
        lines += [f"- {msg}" for msg in warnings]
    return "\n".join(lines) + "\n"


WOKWI_TOML = """[wokwi]
version = 1
elf = "../../../target/thumbv6m-none-eabi/debug/smtlk-firmware"
firmware = "../../../target/thumbv6m-none-eabi/debug/smtlk-firmware"
"""


def main():
    errors = nl.check(nl.PARTS, nl.NETS, nl.REQUIRED)
    if errors:
        for e in errors:
            print(f"ERC: {e}", file=sys.stderr)
        sys.exit(1)
    base = nl.ROOT / "build" / "wokwi"
    (base / "chips").mkdir(parents=True, exist_ok=True)
    (base / "sim").mkdir(parents=True, exist_ok=True)

    diagram, warnings = gen_diagram(nl.NETS)
    for msg in warnings:
        print(f"WARN: {msg}", file=sys.stderr)
    (base / "diagram.json").write_text(json.dumps(diagram, indent=2) + "\n")

    sim, _ = gen_diagram(nl.NETS, sim=True)
    (base / "sim" / "diagram.json").write_text(json.dumps(sim, indent=2) + "\n")
    (base / "sim" / "wokwi.toml").write_text(WOKWI_TOML)

    gen_chip_files(base / "chips")
    (base / "notes.md").write_text(gen_notes(warnings))
    print("wrote build/wokwi/{diagram.json,chips/,sim/,notes.md}")


if __name__ == "__main__":
    main()
```

実行可能にする: `chmod +x circuit/wokwi.py`

- [ ] **Step 4: テストが通ることを確認**

Run: `nix develop -c ./test/wokwi_test.py`
Expected: 全テスト PASS、`all tests passed`

既存テストも壊れていないこと: `nix develop -c ./test/netlist_test.py` → `all tests passed`

- [ ] **Step 5: コミット**

```bash
git add circuit/wokwi.py test/wokwi_test.py
git commit -m "feat(circuit): netlist から Wokwi diagram.json を生成する wokwi.py を追加"
```

---

### Task 2: build.sh への統合

**Files:**
- Modify: `build.sh:19-21`

**Interfaces:**
- Consumes: Task 1 の `circuit/wokwi.py`（実行すると build/wokwi/ に出力、失敗時 exit≠0）
- Produces: `./build.sh` 一発で build/wokwi/ も生成される

- [ ] **Step 1: build.sh の netlist 生成の直後に追記**

`build.sh` の以下の部分:

```bash
echo "== generating netlist (from-to / bom) =="
uv run --script circuit/netlist.py || { echo "FAIL: netlist"; exit 1; }
echo "All parts + netlist built to build/"
```

を次に変更:

```bash
echo "== generating netlist (from-to / bom) =="
uv run --script circuit/netlist.py || { echo "FAIL: netlist"; exit 1; }
echo "== generating wokwi diagram =="
uv run --script circuit/wokwi.py || { echo "FAIL: wokwi"; exit 1; }
echo "All parts + netlist + wokwi built to build/"
```

- [ ] **Step 2: 動作確認**

Run: `./build.sh`
Expected: 末尾に `== generating wokwi diagram ==` と `wrote build/wokwi/...`、exit 0

- [ ] **Step 3: コミット**

```bash
git add build.sh
git commit -m "feat(build): build.sh で Wokwi diagram も生成する"
```

---

### Task 3: flake.nix に wokwi-cli を追加

**Files:**
- Modify: `flake.nix:11-30`（devShell の packages）

**Interfaces:**
- Consumes: なし
- Produces: `nix develop -c wokwi-cli --help` が使える

- [ ] **Step 1: flake.nix に wokwi-cli 派生を追加**

`devShells = forAll (pkgs: {` の直後（`default = pkgs.mkShell {` の前）に let を挟む形で、`forAll` に渡す関数内を次のように変更:

```nix
      devShells = forAll (pkgs: let
        # wokwi-cli は nixpkgs 未収録。GitHub リリースのスタティックバイナリを包む。
        wokwiCliBin = {
          x86_64-linux = {
            suffix = "x64";
            sha256 = "04g873ypgdpxpkzr3vygwg1sd5asp0g79dvsqhr7bbxb1caninbj";
          };
          aarch64-linux = {
            suffix = "arm64";
            sha256 = "1rxi05ci5jj0q1kdh0nx9lr0633vy7lpzcglydmsqkxrdk7w0p90";
          };
        }.${pkgs.system};
        wokwi-cli = pkgs.runCommand "wokwi-cli-0.26.1" {
          src = pkgs.fetchurl {
            url = "https://github.com/wokwi/wokwi-cli/releases/download/v0.26.1/wokwi-cli-linuxstatic-${wokwiCliBin.suffix}";
            inherit (wokwiCliBin) sha256;
          };
        } ''
          mkdir -p $out/bin
          cp $src $out/bin/wokwi-cli
          chmod +x $out/bin/wokwi-cli
        '';
      in {
        default = pkgs.mkShell {
          packages = [
            wokwi-cli         # Wokwi シミュレーション CLI（WOKWI_CLI_TOKEN が必要）
```

既存の `packages = [` 以下（openscad-unstable ほか）はそのまま残す。

- [ ] **Step 2: 動作確認**

Run: `nix develop -c wokwi-cli --version 2>&1 | head -3`
Expected: `0.26.1` を含むバージョン表示（トークン不要で動く）

- [ ] **Step 3: コミット**

```bash
git add flake.nix
git commit -m "feat(nix): wokwi-cli v0.26.1 を devShell に追加"
```

---

### Task 4: wokwi-cli スモーク確認と README 追記

**Files:**
- Modify: `README.md`（回路/コマンドの節に Wokwi の項を追加）

**Interfaces:**
- Consumes: Task 1 の `build/wokwi/sim/`（diagram.json + wokwi.toml）、Task 3 の wokwi-cli
- Produces: 手順が README に載る。スモーク確認の結果報告。

- [ ] **Step 1: ファームをビルドして ELF を用意**

Run: `nix develop -c cargo build --locked`
Expected: `target/thumbv6m-none-eabi/debug/smtlk-firmware` が生成される

- [ ] **Step 2: スモーク実行（トークンがある場合のみ）**

`WOKWI_CLI_TOKEN` が環境に無ければこのステップはスキップし、その旨を報告する（トークンは https://wokwi.com/dashboard/ci から無料取得できることを README に書く）。

Run: `nix develop -c wokwi-cli --timeout 10000 build/wokwi/sim`
Expected: diagram の読み込みに成功し、シミュレーションが起動する（10 秒でタイムアウト終了、exit 0）。ゴールは「diagram.json が読み込めてファームが起動する」ことで、WiFi 接続の成否は追わない。失敗した場合は失敗として報告し、原因（部品タイプ名・ピン名・ELF 形式など）を切り分ける。

- [ ] **Step 3: README に Wokwi の項を追記**

README.md の回路まわりの節（from-to / bom に触れている箇所の近く）に追加。コマンド例のブロック内にはコメントを書かず、説明は地の文に書く:

```markdown
### Wokwi 配線見本

`./build.sh`（または `nix develop -c uv run --script circuit/wokwi.py`）で
`build/wokwi/` に Wokwi 用の配線見本が生成される。

- `diagram.json` + `chips/` — wokwi.com に貼って見る配線見本（全部品・全 net）。
  手順は `build/wokwi/notes.md` 参照。
- `sim/` — wokwi-cli 用の簡略版（カスタムチップ抜き）。実行にはファームの
  ビルドと `WOKWI_CLI_TOKEN`（https://wokwi.com/dashboard/ci で無料取得）が必要。

wokwi-cli でのシミュレーション:

```
nix develop -c cargo build --locked
WOKWI_CLI_TOKEN=... nix develop -c wokwi-cli build/wokwi/sim
```
```

- [ ] **Step 4: 確認とコミット**

Run: `nix develop -c ./test/wokwi_test.py && nix develop -c ./test/netlist_test.py`
Expected: 両方 `all tests passed`

```bash
git add README.md
git commit -m "docs(readme): Wokwi 配線見本の生成・確認手順を追記"
```

---

## Self-Review 結果

- スペック網羅: 生成スクリプト(Task 1)、カスタムチップ(Task 1)、notes.md(Task 1)、wokwi-cli+nix(Task 3)、wokwi.toml(Task 1)、build.sh 統合(Task 2)、テスト(Task 1)、エラー処理＝警告+notes.md 記録(Task 1)。スペックの「未対応 ref は notes.md に記録」「ピン名がマッピングできなければ exit 1」のうち後者は、endpoint 検証テストと ERC 前提で担保（不明 ref は警告、不明 pin は netlist.py の ERC が先に落とす）。
- スペックからの逸脱（設計中に判明した制約による）: wokwi-cli はカスタムチップに compiled wasm を要求するため、CLI 用には `sim/`（カスタムチップ抜き・サーボ GND を Pico に直結）を併産する 2 段構えに変更。wokwi.toml は `circuit/wokwi/` ではなく `build/wokwi/sim/` に生成（diagram.json と同居が必要なため）。
- プレースホルダ: なし。ハッシュ・バージョン・ピン名は事前確認済みの実値。
- 型整合: `gen_diagram(nets, sim=False) -> (dict, list[str])`、`wokwi_endpoints -> list[str]` をテストとスクリプトで一致確認済み。
