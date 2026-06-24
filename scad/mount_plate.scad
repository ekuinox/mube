include <params.scad>

// Fit-check mount face:
//  - flat tape face over the body footprint (centered at the body center)
//  - rosette registration hole at the axis (origin) — Ø46+clearance through the
//    plate; the raised escutcheon pokes through and sets coaxial position
//    (circular => registration only, no torque reaction)
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
      // 4mm short of clear_down. Overlaps the floor by 1mm to fuse.
      translate([-brace_stub_w/2, -(clear_down - 4), 0])
        cube([brace_stub_w, (clear_down - 4) - ext_down + 1, wall]);
    }
    // rosette registration / clearance hole at the axis
    translate([0, 0, -0.1])
      cylinder(d = rosette_d + fit_clearance, h = wall + 0.2);
  }
}
