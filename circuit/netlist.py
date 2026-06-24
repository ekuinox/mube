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
