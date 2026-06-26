// Render harness for servo_mounts(): proves the module exists and renders
// to a manifold STL with two pilot-drilled bosses. params asserts also run.
include <../scad/params.scad>
use <../scad/hardware.scad>

servo_mounts();
