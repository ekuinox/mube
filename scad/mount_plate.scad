include <params.scad>

// Fit-check mount face:
//  - flat tape face over the body footprint (centered at the body center)
//  - rosette recess at the axis (origin) — Ø46+clearance shallow recess
//    (depth = rosette_recess) that registers/clears the raised escutcheon
//    while leaving a thin floor so the brace stub bridge stays attached.
//    If the real escutcheon is taller than rosette_recess, increase it
//    (fit-check), accepting a thinner floor.
//    (circular => registration only, no torque reaction)
//    Note: the central servo-shaft passage is cut by body.scad's sg90_cutout.
//  - downward brace stub toward the door handle (-Y); a fit-check placeholder
//    for the torque reaction, refined against the real handle next phase
// FUTURE (Q6): replace the brace stub with the measured handle/frame engagement.
module mount_plate() {
  difference() {
    union() {
      // flat footprint
      translate([center_x, center_y, 0])
        linear_extrude(height = wall)
          offset(r = 2) offset(r = -2)
            square([body_l, body_w], center = true);
      // downward brace stub: from the bottom wall toward the handle, stopping
      // 4mm short of clear_down. Overlaps the floor to fuse with the plate.
      translate([-brace_stub_w/2, -(clear_down - 4), 0])
        cube([brace_stub_w, (clear_down - 4) - ext_down + 1, wall]);
    }
    // rosette shallow recess at the axis — depth rosette_recess only,
    // so the floor and brace stub bridge are never severed.
    translate([0, 0, -0.1])
      cylinder(d = rosette_d + fit_clearance, h = rosette_recess + 0.1);
  }
}
