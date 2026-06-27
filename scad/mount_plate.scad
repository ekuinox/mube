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

      // pedestal top platform — disc with shaft hole
      translate([0, 0, pedestal_top_z - wall])
        linear_extrude(height = wall)
          difference() {
            circle(r = pedestal_r);
            circle(d = servo_shaft_d + 2*c);
          }

      // servo screw bosses on pedestal top
      for (sx = [-1, 1])
        translate([sx * servo_screw_span/2, 0, pedestal_top_z])
          difference() {
            cylinder(d = servo_boss_d, h = servo_boss_h);
            translate([0, 0, -0.1])
              cylinder(d = servo_screw_pilot, h = servo_boss_h + 0.2);
          }

      // brace stub toward the handle (-Y)
      translate([-brace_stub_w/2, -(clear_down - 4), 0])
        cube([brace_stub_w, (clear_down - 4) - ext_down + 1, wall]);
    }

    // central floor opening for thumb-turn knob
    translate([0, 0, -0.1])
      cylinder(d = rosette_d + c, h = wall + 0.2);
  }
}
