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
