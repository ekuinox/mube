#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.10"
# dependencies = []
# ///
"""
Smart-lock circuit as code: parts, GPIO assignment, and nets in one source.
Runs an ERC-lite check, then generates build/from-to.md and build/bom.md.

    nix develop
    uv run --script circuit/netlist.py      # or just: ./circuit/netlist.py

Zero dependencies; uv provisions Python. Generated files land in build/ and
are git-ignored — only this file is committed.
"""
from __future__ import annotations
import sys
import pathlib


def check(parts, nets, required):
    """Return a list of ERC error strings. Empty list means the netlist is valid."""
    errors = []
    pin_nets = {}
    for nname, eps in nets.items():
        for (ref, pin) in eps:
            if ref not in parts or pin not in parts[ref]:
                errors.append(f"net {nname} references unknown pin {ref}.{pin}")
                continue
            pin_nets.setdefault((ref, pin), []).append(nname)
    for nname, eps in nets.items():
        if len(eps) < 2:
            errors.append(f"net {nname} has fewer than 2 endpoints")
    for ref, pins in parts.items():
        for pin in pins:
            owners = pin_nets.get((ref, pin), [])
            if len(owners) == 0:
                errors.append(f"{ref}.{pin} is not connected to any net")
            elif len(owners) > 1:
                errors.append(f"{ref}.{pin} is connected to multiple nets: {', '.join(owners)}")
    for r in required:
        if r not in nets:
            errors.append(f"required net {r} is missing")
    return errors


def gen_from_to(nets):
    """Markdown wiring guide: chain each net's endpoints into from->to pairs."""
    lines = ["# Wiring (from-to)", ""]
    for name, eps in nets.items():
        lines.append(f"## {name}")
        pins = [f"{ref}.{pin}" for ref, pin in eps]
        for a, b in zip(pins, pins[1:]):
            lines.append(f"- {a} -> {b}")
        lines.append("")
    return "\n".join(lines).rstrip() + "\n"


def gen_bom(part_meta):
    """Markdown BOM table, one row per ref (qty 1)."""
    lines = ["# BOM", "", "| Ref | Part | Value | Qty |", "|-----|------|-------|-----|"]
    for ref, (name, value) in part_meta.items():
        lines.append(f"| {ref} | {name} | {value} | 1 |")
    return "\n".join(lines) + "\n"


ROOT = pathlib.Path(__file__).resolve().parent.parent

# Provisional GPIO assignment — finalized in the firmware phase. Change here and
# from-to.md follows.
GPIO = {"servo": "GP15", "gate": "GP14", "led": "GP16", "btn": "GP17"}

PARTS = {
    "U1": ["VBUS", "GND", GPIO["servo"], GPIO["gate"], GPIO["led"], GPIO["btn"]],
    "M1": ["V+", "GND", "SIG"],
    "Q1": ["G", "D", "S"],
    "Rg": ["1", "2"],
    "Rgs": ["1", "2"],
    "Rled": ["1", "2"],
    "D1": ["A", "K"],
    "SW1": ["1", "2"],
    "C1": ["+", "-"],
}

PART_META = {
    "U1": ("Raspberry Pi Pico W", "-"),
    "M1": ("SG90 servo", "3-wire"),
    "Q1": ("N-ch MOSFET (logic level)", "AO3400 / IRLZ44N"),
    "Rg": ("Resistor", "220R"),
    "Rgs": ("Resistor", "10k"),
    "Rled": ("Resistor", "330R"),
    "D1": ("LED", "5mm"),
    "SW1": ("Tactile switch", "-"),
    "C1": ("Electrolytic cap", "470uF"),
}


def build_nets(gpio):
    """Build the net dict from a GPIO assignment so changes flow into outputs."""
    return {
        "+5V": [("U1", "VBUS"), ("M1", "V+"), ("C1", "+")],
        "GND": [("U1", "GND"), ("Q1", "S"), ("C1", "-"),
                ("Rgs", "2"), ("D1", "K"), ("SW1", "2")],
        "SERVO_RTN": [("M1", "GND"), ("Q1", "D")],
        "SERVO_SIG": [("U1", gpio["servo"]), ("M1", "SIG")],
        "GATE_DRV": [("U1", gpio["gate"]), ("Rg", "1")],
        "GATE": [("Rg", "2"), ("Q1", "G"), ("Rgs", "1")],
        "LED_DRV": [("U1", gpio["led"]), ("Rled", "1")],
        "LED_A": [("Rled", "2"), ("D1", "A")],
        "BTN": [("U1", gpio["btn"]), ("SW1", "1")],
    }


NETS = build_nets(GPIO)
REQUIRED = ["+5V", "GND", "SERVO_RTN"]


def main():
    errors = check(PARTS, NETS, REQUIRED)
    if errors:
        for e in errors:
            print(f"ERC: {e}", file=sys.stderr)
        sys.exit(1)
    out = ROOT / "build"
    out.mkdir(exist_ok=True)
    (out / "from-to.md").write_text(gen_from_to(NETS))
    (out / "bom.md").write_text(gen_bom(PART_META))
    print("wrote build/from-to.md, build/bom.md")


if __name__ == "__main__":
    main()
