include <params.scad>

// Pedestal: cup-shaped structure that wraps around the rosette/socket area,
// providing a platform for the SG90 servo tabs.
//
// Structure (Z cross-section at the axis):
//   Z=0..wall:              body floor (with central opening for knob)
//   Z=wall..pedestal_top_z: pedestal walls rising around the rosette
//   Z=pedestal_top_z:       platform where servo tabs rest (with shaft hole)
//
// The brace stub is retained for torque reaction toward the door handle (-Y).
module mount_plate() {
  c = fit_clearance;
  pedestal_r = rosette_d/2 + pedestal_wall_t + c;

  difference() {
    union() {
      // body floor — full footprint
      translate([center_x, center_y, 0])
        linear_extrude(height = wall)
          offset(r = 2) offset(r = -2)
            square([body_l, body_w], center = true);

      // pedestal walls — cylindrical ring from floor to platform
      linear_extrude(height = pedestal_top_z)
        difference() {
          circle(r = pedestal_r);
          circle(r = pedestal_r - pedestal_wall_t);
        }

      // pedestal top platform — thick disc the servo tabs screw straight into.
      // M2 self-tapping engages the full servo_plate_t (pilot holes are through).
      // The servo case/gear head passes through via sg90_cutout's lower block;
      // only the tabs rest on this plate.
      translate([0, 0, pedestal_top_z - servo_plate_t])
        linear_extrude(height = servo_plate_t)
          difference() {
            circle(r = pedestal_r);
            circle(d = servo_shaft_d + 2*c);
            // pilot holes are centered on the servo BODY (shifted by
            // servo_shaft_offset), not on the shaft axis at the origin
            for (sx = [-1, 1])
              translate([servo_shaft_offset + sx * servo_screw_span/2, 0])
                circle(d = servo_screw_pilot);
          }

    }

    // central floor opening for thumb-turn knob
    translate([0, 0, -0.1])
      cylinder(d = rosette_d + c, h = wall + 0.2);
  }
}
