include <../scad/params.scad>
// Derived body must enclose the largest component footprints.
assert(body_l >= pico_l + 2*wall, "body length must enclose Pico");
assert(body_h >= servo_body_h + 2*wall, "body height must enclose servo");
assert(fit_clearance >= 0, "clearance non-negative");
echo("params_test ok");

// Render a minimal object to satisfy OpenSCAD's requirement
sphere(0.01, $fn=3);
