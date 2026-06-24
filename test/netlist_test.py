#!/usr/bin/env python3
# /// script
# requires-python = ">=3.10"
# dependencies = []
# ///
"""Tests for circuit/netlist.py. Run: ./test/netlist_test.py"""
import sys, pathlib, subprocess

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
    test_real_circuit_passes_erc,
    test_every_part_pin_is_used,
    test_gpio_change_flows_to_from_to,
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
