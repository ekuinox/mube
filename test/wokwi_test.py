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
    assert frozenset(("servo:V+", "pico:VBUS")) in got


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
