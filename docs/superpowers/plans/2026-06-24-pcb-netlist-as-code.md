# Code-Based Netlist / From-To Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Define the smart-lock circuit as a single text source (`circuit/netlist.py`), validate the wiring with a dependency-free ERC check, and generate a from-to wiring guide plus a BOM for hand-wiring a perfboard.

**Architecture:** One PEP 723 `uv run --script` Python file holds the circuit data (parts, GPIO assignment, nets) plus three pure functions: `check()` (ERC-lite), `gen_from_to()`, `gen_bom()`. A guarded `main()` runs the check and, on success, writes `build/from-to.md` and `build/bom.md`. Generated files are derivatives (git-ignored, like STL); only `netlist.py` is committed. Tests import the pure functions and exercise them with both the real circuit and deliberately-broken netlists.

**Tech Stack:** Python 3.10+ run via `uv` (PEP 723 inline metadata, zero dependencies). No KiCad / EDA / gerber. Matches the existing `viewer/serve.py` convention.

## Global Constraints

- Runner: `#!/usr/bin/env -S uv run --script` with PEP 723 header `requires-python = ">=3.10"`, `dependencies = []`. Copy this exact pattern from `viewer/serve.py:1-5`.
- Zero third-party dependencies. Standard library only.
- Source of truth `circuit/netlist.py` is committed. Generated `build/from-to.md` and `build/bom.md` are NOT committed (`build/` is already in `.gitignore`).
- ERC violations must print to stderr and cause a non-zero exit.
- GPIO numbers are provisional and MUST be variable-ized (a `GPIO` dict), so the firmware phase can change them and have from-to.md follow.
- Series passives separate nets: a resistor never shares one net across both terminals.
- End every commit message with:
  `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`

---

### Task 1: ERC check engine

**Files:**
- Create: `circuit/netlist.py`
- Test: `test/netlist_test.py`

**Interfaces:**
- Consumes: nothing.
- Produces: `check(parts, nets, required) -> list[str]`
  - `parts`: `dict[str, list[str]]` — ref → pin names (e.g. `{"Q1": ["G","D","S"]}`).
  - `nets`: `dict[str, list[tuple[str, str]]]` — net name → list of `(ref, pin)` endpoints.
  - `required`: `Iterable[str]` — net names that must exist.
  - Returns a list of human-readable error strings (empty list = pass).
  - Error message formats (exact substrings, tests depend on them):
    - `"net {name} references unknown pin {ref}.{pin}"`
    - `"net {name} has fewer than 2 endpoints"`
    - `"{ref}.{pin} is not connected to any net"`
    - `"{ref}.{pin} is connected to multiple nets: {a}, {b}"`
    - `"required net {name} is missing"`

- [ ] **Step 1: Write the failing test**

Create `test/netlist_test.py`:

```python
#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.10"
# dependencies = []
# ///
"""Tests for circuit/netlist.py. Run: ./test/netlist_test.py"""
import sys, pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "circuit"))
import netlist as n

GOOD_PARTS = {"A": ["1", "2"], "B": ["1", "2"]}
GOOD_NETS = {"N1": [("A", "1"), ("B", "1")], "N2": [("A", "2"), ("B", "2")]}


def test_good_netlist_passes():
    assert n.check(GOOD_PARTS, GOOD_NETS, ["N1"]) == []


def test_unconnected_pin_detected():
    parts = {"A": ["1", "2", "3"], "B": ["1", "2"]}
    errs = n.check(parts, GOOD_NETS, ["N1"])
    assert any("A.3 is not connected" in e for e in errs), errs


def test_isolated_net_detected():
    nets = {"N1": [("A", "1")], "N2": [("A", "2"), ("B", "2")], "X": [("B", "1")]}
    errs = n.check(GOOD_PARTS, nets, ["N1"])
    assert any("fewer than 2 endpoints" in e for e in errs), errs


def test_double_connected_pin_detected():
    nets = {"N1": [("A", "1"), ("B", "1")], "N2": [("A", "2"), ("B", "2")],
            "N3": [("A", "1"), ("B", "2")]}
    errs = n.check(GOOD_PARTS, nets, ["N1"])
    assert any("A.1 is connected to multiple nets" in e for e in errs), errs


def test_missing_required_net_detected():
    errs = n.check(GOOD_PARTS, GOOD_NETS, ["N1", "GND"])
    assert any("required net GND is missing" in e for e in errs), errs


def test_unknown_pin_detected():
    nets = {"N1": [("A", "9"), ("B", "1")], "N2": [("A", "1"), ("A", "2")],
            "N3": [("B", "2")]}
    errs = n.check(GOOD_PARTS, nets, ["N1"])
    assert any("references unknown pin A.9" in e for e in errs), errs


TESTS = [
    test_good_netlist_passes,
    test_unconnected_pin_detected,
    test_isolated_net_detected,
    test_double_connected_pin_detected,
    test_missing_required_net_detected,
    test_unknown_pin_detected,
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

Then make it executable: `chmod +x test/netlist_test.py`

- [ ] **Step 2: Run test to verify it fails**

Run: `./test/netlist_test.py`
Expected: FAIL — `ModuleNotFoundError: No module named 'netlist'` (the file does not exist yet).

- [ ] **Step 3: Write minimal implementation**

Create `circuit/netlist.py`:

```python
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
```

- [ ] **Step 4: Run test to verify it passes**

Run: `./test/netlist_test.py`
Expected: PASS — all 6 tests print `PASS`, ends with `all tests passed`.

- [ ] **Step 5: Commit**

```bash
git add circuit/netlist.py test/netlist_test.py
git commit -m "feat: ERC-lite netlist check engine

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 2: from-to and BOM generators

**Files:**
- Modify: `circuit/netlist.py`
- Test: `test/netlist_test.py`

**Interfaces:**
- Consumes: nothing from Task 1 (independent pure functions in the same file).
- Produces:
  - `gen_from_to(nets) -> str` — Markdown. One `## {net}` heading per net, then chained `- {ref}.{pin} -> {ref}.{pin}` lines pairing consecutive endpoints (endpoint `i` to endpoint `i+1`).
  - `gen_bom(part_meta) -> str` — Markdown table. `part_meta` is `dict[str, tuple[str, str]]` (ref → (name, value)); one row `| ref | name | value | 1 |` per entry under header `| Ref | Part | Value | Qty |`.

- [ ] **Step 1: Write the failing test**

Add these test functions to `test/netlist_test.py` (above the `TESTS = [...]` list):

```python
def test_gen_from_to_chains_endpoints():
    nets = {"GND": [("U1", "GND"), ("Q1", "S"), ("C1", "-")]}
    md = n.gen_from_to(nets)
    assert "## GND" in md
    assert "- U1.GND -> Q1.S" in md
    assert "- Q1.S -> C1.-" in md


def test_gen_from_to_single_pair():
    nets = {"SERVO_SIG": [("U1", "GP15"), ("M1", "SIG")]}
    md = n.gen_from_to(nets)
    assert "- U1.GP15 -> M1.SIG" in md


def test_gen_bom_rows():
    meta = {"Q1": ("N-ch MOSFET (logic level)", "AO3400 / IRLZ44N"),
            "Rg": ("Resistor", "220R")}
    md = n.gen_bom(meta)
    assert "| Ref | Part | Value | Qty |" in md
    assert "| Q1 | N-ch MOSFET (logic level) | AO3400 / IRLZ44N | 1 |" in md
    assert "| Rg | Resistor | 220R | 1 |" in md
```

Add their names to the `TESTS` list:

```python
TESTS = [
    test_good_netlist_passes,
    test_unconnected_pin_detected,
    test_isolated_net_detected,
    test_double_connected_pin_detected,
    test_missing_required_net_detected,
    test_unknown_pin_detected,
    test_gen_from_to_chains_endpoints,
    test_gen_from_to_single_pair,
    test_gen_bom_rows,
]
```

- [ ] **Step 2: Run test to verify it fails**

Run: `./test/netlist_test.py`
Expected: FAIL — `AttributeError: module 'netlist' has no attribute 'gen_from_to'` (raised as an error in the first new test; earlier tests still PASS).

- [ ] **Step 3: Write minimal implementation**

Append to `circuit/netlist.py` (after `check`):

```python
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
```

- [ ] **Step 4: Run test to verify it passes**

Run: `./test/netlist_test.py`
Expected: PASS — all 9 tests print `PASS`, ends with `all tests passed`.

- [ ] **Step 5: Commit**

```bash
git add circuit/netlist.py test/netlist_test.py
git commit -m "feat: from-to and BOM generators

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 3: Circuit data + main(), and run it

**Files:**
- Modify: `circuit/netlist.py`
- Test: `test/netlist_test.py`

**Interfaces:**
- Consumes: `check`, `gen_from_to`, `gen_bom` from Tasks 1-2.
- Produces (module-level names in `netlist.py`):
  - `GPIO: dict[str, str]` — `{"servo","gate","led","btn"}` → `"GP15"` etc.
  - `PARTS: dict[str, list[str]]`, `PART_META: dict[str, tuple[str, str]]`, `NETS: dict[str, list[tuple[str,str]]]`, `REQUIRED: list[str]`.
  - `ROOT: pathlib.Path` (repo root), `main()` guarded by `if __name__ == "__main__"`.

**Net derivation (series passives split nets — this is the substance of the design):**
- `+5V`: U1.VBUS, M1.V+, C1.+
- `GND`: U1.GND, Q1.S, C1.-, Rgs.2, D1.K, SW1.2
- `SERVO_RTN`: M1.GND, Q1.D
- `SERVO_SIG`: U1.GP15, M1.SIG
- `GATE_DRV`: U1.GP14, Rg.1
- `GATE`: Rg.2, Q1.G, Rgs.1
- `LED_DRV`: U1.GP16, Rled.1
- `LED_A`: Rled.2, D1.A
- `BTN`: U1.GP17, SW1.1

- [ ] **Step 1: Write the failing test**

Add to `test/netlist_test.py` (above `TESTS = [...]`):

```python
import subprocess


def test_real_circuit_passes_erc():
    assert n.check(n.PARTS, n.NETS, n.REQUIRED) == []


def test_every_part_pin_is_used():
    used = {(ref, pin) for eps in n.NETS.values() for ref, pin in eps}
    for ref, pins in n.PARTS.items():
        for pin in pins:
            assert (ref, pin) in used, f"{ref}.{pin} unused"


def test_gpio_change_flows_to_from_to():
    saved = dict(n.GPIO)
    try:
        n.GPIO["servo"] = "GP99"
        nets = n.build_nets(n.GPIO)
        assert any(("U1", "GP99") in eps for eps in nets.values())
    finally:
        n.GPIO.clear()
        n.GPIO.update(saved)


def test_main_generates_files():
    out = subprocess.run([str(ROOT / "circuit" / "netlist.py")],
                         capture_output=True, text=True)
    assert out.returncode == 0, out.stderr
    assert (ROOT / "build" / "from-to.md").exists()
    assert (ROOT / "build" / "bom.md").exists()
```

Add their names to the `TESTS` list (append after the Task 2 entries):

```python
    test_real_circuit_passes_erc,
    test_every_part_pin_is_used,
    test_gpio_change_flows_to_from_to,
    test_main_generates_files,
```

- [ ] **Step 2: Run test to verify it fails**

Run: `./test/netlist_test.py`
Expected: FAIL — `AttributeError: module 'netlist' has no attribute 'PARTS'` (in the first new test; earlier tests still PASS).

- [ ] **Step 3: Write minimal implementation**

Append to `circuit/netlist.py` (after the generators, before nothing else):

```python
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
```

Then make it executable: `chmod +x circuit/netlist.py`

- [ ] **Step 4: Run test to verify it passes**

Run: `./test/netlist_test.py`
Expected: PASS — all 13 tests print `PASS`, ends with `all tests passed`.

Also confirm the generated output by hand:

Run: `./circuit/netlist.py && cat build/from-to.md build/bom.md`
Expected: prints `wrote build/from-to.md, build/bom.md`, then the wiring guide (with `## GATE_DRV` / `## GATE` split) and the BOM table.

- [ ] **Step 5: Commit**

```bash
git add circuit/netlist.py test/netlist_test.py
git commit -m "feat: smart-lock circuit data + generation entrypoint

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 4: Repository integration (build.sh + README)

**Files:**
- Modify: `build.sh:18-19`
- Modify: `README.md`

**Interfaces:**
- Consumes: `circuit/netlist.py` from Task 3.
- Produces: nothing for other tasks (final integration).

- [ ] **Step 1: Add netlist generation to build.sh**

In `build.sh`, after the STL build loop ends and before the final `echo`, insert a netlist step. Change:

```bash
echo "All parts built to build/"
```

to:

```bash
echo "== generating netlist (from-to / bom) =="
uv run --script circuit/netlist.py || { echo "FAIL: netlist"; exit 1; }
echo "All parts + netlist built to build/"
```

Note: `build.sh` already re-execs inside `nix develop` (lines 4-7), so `uv` is on PATH.

- [ ] **Step 2: Run build.sh to verify**

Run: `./build.sh`
Expected: builds body/lid/socket STL, then prints `== generating netlist ==`, `wrote build/from-to.md, build/bom.md`, and `All parts + netlist built to build/`. Exit code 0.

- [ ] **Step 3: Document in README**

In `README.md`, after the "## テスト" section (currently lines 14-16), add:

```markdown
## 基板（電気設計・手配線用）
    uv run --script circuit/netlist.py   # = ./circuit/netlist.py

回路を `circuit/netlist.py` にコードで定義し、ERC ライト（結線チェック）の後に
`build/from-to.md`（手配線手順表）と `build/bom.md`（部品表）を生成する。
GPIO 番号は仮で `netlist.py` の `GPIO` 変数に隔離（ファームで確定後に差し替え）。
生成物は STL と同様 build/ で非コミット。テストは `./test/netlist_test.py`。
```

- [ ] **Step 4: Verify README + test still pass**

Run: `./test/netlist_test.py`
Expected: PASS — `all tests passed`.

- [ ] **Step 5: Commit**

```bash
git add build.sh README.md
git commit -m "feat: wire netlist generation into build.sh and document it

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Self-Review

**Spec coverage:**
- Spec §2 repo layout (`circuit/netlist.py`, `build/from-to.md`, `build/bom.md`, `test/netlist_test`) → Tasks 1-4. ✓
- Spec §3 circuit (parts, nets, Rgs, C1, VBUS, GPIO variable-ized) → Task 3 `PARTS`/`PART_META`/`build_nets`/`GPIO`. ✓ (GATE/LED nets split for series-resistor correctness, noted in plan header and Task 3.)
- Spec §4 tool responsibilities (definition, ERC, generators) → Tasks 1-3. ✓
- Spec §5 output formats (from-to chained per net, BOM table) → Task 2. ✓
- Spec §6 integration (uv run, build.sh, .gitignore, test) → Task 4 + Task 1 test file. `.gitignore` already ignores `build/` — no change needed. ✓
- Spec §7 completion checks (runs & generates, good passes, broken fails non-zero, GPIO change flows through) → Tasks 1 & 3 tests (`test_main_generates_files`, ERC failure tests, `test_gpio_change_flows_to_from_to`). ✓

**Placeholder scan:** No TBD/TODO; every code step shows complete code. ✓

**Type consistency:** `check(parts, nets, required)`, `gen_from_to(nets)`, `gen_bom(part_meta)`, `build_nets(gpio)`, and `GPIO`/`PARTS`/`PART_META`/`NETS`/`REQUIRED` names are used identically across tasks and tests. ✓
