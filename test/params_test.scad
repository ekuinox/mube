include <../scad/params.scad>
assert(body_l > 0 && body_w > 0, "positive plate dims");
assert(ext_left <= clear_left, "left extent within door clearance");
assert(ext_down <= clear_down, "down extent within handle clearance");
assert(knob_w_top <= knob_w_base, "knob tapers base->top");
assert(knob_engage < knob_h, "engagement shallower than protrusion");
echo("params_test ok");
sphere(0.01, $fn = 3);
