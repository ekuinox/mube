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
        color = NET_COLORS[name] if name in NET_COLORS else next(palette)
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
