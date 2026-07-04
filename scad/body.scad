include <params.scad>
use <hardware.scad>
use <mount_plate.scad>

// Origin = thumb-turn / servo axis (center of the door rosette).
// The body center is offset to (center_x, center_y): the axis sits low-left so
// -X stays within clear_left and -Y within clear_down; the body grows +X/+Y.
module body() {
  // Servo on the axis; shaft points down through pedestal.
  servo_x = 0;
  servo_y = 0;

  // USB on the +Y top wall, aligned to the Pico's top end.
  wall_y_top = center_y + inner_w/2;
  usb_z = wall + tray_t + pico_boss_h + pico_h + usb_connector_h/2;

  difference() {
    union() {
      // outer shell (open top)
      difference() {
        translate([center_x, center_y, body_h/2])
          rounded_box(body_l, body_w, body_h, box_corner_r);
        translate([center_x, center_y, body_h/2 + wall])
          rounded_box(inner_l, inner_w, body_h,
                      box_corner_r - wall > 0 ? box_corner_r - wall : 0.5);
      }
      // bottom mount face with pedestal
      mount_plate();
      // tray connector bosses on the floor (tray carries Pico + board)
      translate([pico_x, pico_y, wall])
        tray_mounts();
    }

    // servo pocket at pedestal top; tabs rest on pedestal surface
    translate([servo_x, servo_y, pedestal_top_z + servo_body_h/2])
      sg90_cutout();

    // floor opening for thumb-turn knob (through mount plate center)
    translate([0, 0, -0.1])
      cylinder(d = rosette_d + fit_clearance, h = wall + 0.2);

    // USB on the +Y top wall
    translate([pico_x, wall_y_top, usb_z])
      usb_cutout();
  }
}

module rounded_box(l, w, h, r) {
  linear_extrude(height = h, center = true)
    offset(r = r) offset(r = -r)
      square([l, w], center = true);
}
