include <params.scad>

// Thumb-turn socket. Knob pocket on top (+Z) tapers from the tip (deep) to the
// base (opening); servo shaft bore on the bottom (-Z).
module thumbturn_socket() {
  c   = fit_clearance;
  ow  = knob_w_base + knob_t + 2*socket_wall;   // outer footprint (use widest)
  oh  = knob_engage + socket_wall + 6;          // total height incl. shaft collar
  difference() {
    // outer body: rounded square prism
    linear_extrude(height = oh)
      offset(r = 2) offset(r = -2)
        square([ow, ow], center = true);
    // tapered knob pocket: base (knob_w_base) at the top opening, narrowing to
    // the tip (knob_w_top) at depth. Built tip-square at bottom, scaled up to base.
    translate([0, 0, oh - knob_engage])
      linear_extrude(height = knob_engage + 0.1, scale = [knob_w_base/knob_w_top, 1])
        offset(r = c) square([knob_w_top, knob_t], center = true);
    // servo shaft bore (bottom)
    translate([0, 0, -0.1])
      cylinder(d = servo_shaft_d + c, h = 6 + 0.1);
  }
}
