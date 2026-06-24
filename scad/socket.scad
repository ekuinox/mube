include <params.scad>

// Parametric thumb-turn socket. Knob pocket on top (+Z), servo shaft bore on bottom (-Z).
module thumbturn_socket() {
  c   = fit_clearance;
  ow  = knob_w + knob_t + 2*socket_wall;   // outer footprint, generous
  oh  = knob_h + socket_wall + 6;          // total height incl. shaft collar
  difference() {
    // outer body: rounded square prism
    linear_extrude(height = oh)
      offset(r = 2) offset(r = -2)
        square([ow, ow], center = true);
    // knob pocket (top): rectangular slot sized to the real knob
    translate([0, 0, oh - knob_h])
      linear_extrude(height = knob_h + 0.1)
        offset(r = c) square([knob_w, knob_t], center = true);
    // servo shaft bore (bottom)
    translate([0, 0, -0.1])
      cylinder(d = servo_shaft_d + c, h = 6 + 0.1);
  }
}
