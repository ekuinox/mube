include <params.scad>

// Thumb-turn socket. Knob pocket on top (+Z) tapers from the tip (deep) to the
// base (opening); servo shaft bore on the bottom (-Z).
module thumbturn_socket() {
  c   = fit_clearance;
  hc  = horn_clearance;
  // outer footprint is knob-driven and capped so the R6-rounded body still clears the
  // pedestal bore (~rosette_d). The horn cross-slot (33.3mm) just fits inside this.
  ow  = knob_w_base + knob_t + 2*socket_wall;
  difference() {
    // outer body: rounded square prism (R=6 for pedestal clearance)
    linear_extrude(height = socket_oh)
      offset(r = 6) offset(r = -6)
        square([ow, ow], center = true);
    // tapered knob pocket: base (knob_w_base) at the top opening, narrowing to
    // the tip (knob_w_top) at depth. Built tip-square at bottom, scaled up to base.
    translate([0, 0, socket_oh - knob_engage])
      linear_extrude(height = knob_engage + 0.1, scale = [knob_w_base/knob_w_top, 1])
        offset(r = c) square([knob_w_top, knob_t], center = true);
    // horn bar pocket: single tapered bar + hub circle (bottom face = shaft side)
    translate([0, 0, -0.1]) {
      linear_extrude(height = horn_thick + hc + 0.1)
        offset(r = hc)
          union() {
            polygon([
              [-horn_arm_l, -horn_arm_w_tip/2],
              [          0, -horn_arm_w_base/2],
              [ horn_arm_l, -horn_arm_w_tip/2],
              [ horn_arm_l,  horn_arm_w_tip/2],
              [          0,  horn_arm_w_base/2],
              [-horn_arm_l,  horn_arm_w_tip/2]
            ]);
            circle(d = horn_hub_d);
          }
    }
  }
  // center registration stub: a nub protruding from the pocket floor (~half the horn
  // thickness) that nests into the horn's central recess (horn_stub_d, measured) to
  // stop the horn shifting up/down/left/right. No center retaining screw is used.
  translate([0, 0, (horn_thick + hc) - horn_thick/2])
    cylinder(d = horn_stub_d, h = horn_thick/2 + 0.1);
}
