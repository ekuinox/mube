include <params.scad>
use <hardware.scad>
use <mount_plate.scad>

// Origin = thumb-turn / servo axis (center of the door rosette).
// The body center is offset to (center_x, center_y): the axis sits low-left so
// -X stays within clear_left and -Y within clear_down; the body grows +X/+Y.
module body() {
  // Servo on the axis; shaft points down through the bottom.
  servo_x = 0;
  servo_y = 0;

  // Pico stacked above the servo in free +Y space; long axis along Y
  // (rotate the X-oriented pico_w_mounts by 90 deg).
  pico_x = 0;
  pico_gap = max(6, rosette_d/2 - servo_body_w/2 + 2);
  pico_y = servo_body_w/2 + pico_gap + pico_l/2;

  // MOSFET keep-out on the free +X side, clear of servo and Pico.
  mosfet_x = ext_right - mosfet_l/2 - 2;
  mosfet_y = center_y;

  // LED + button on the +X right wall, spaced around center_y.
  wall_x = center_x + inner_l/2;     // right interior wall plane
  led_y  = center_y - led_btn_spacing/2;
  btn_y  = center_y + led_btn_spacing/2;

  // USB on the +Y top wall, aligned to the Pico's top end.
  wall_y_top = center_y + inner_w/2;

  difference() {
    union() {
      // outer shell (open top), centered at (center_x, center_y)
      difference() {
        translate([center_x, center_y, body_h/2])
          rounded_box(body_l, body_w, body_h, box_corner_r);
        translate([center_x, center_y, body_h/2 + wall])
          rounded_box(inner_l, inner_w, body_h,
                      box_corner_r - wall > 0 ? box_corner_r - wall : 0.5);
      }
      // bottom mount face (also centered at center_x/center_y internally)
      mount_plate();
      // Pico standoffs, long axis along Y
      translate([pico_x, pico_y, wall*0.5])
        rotate([0, 0, 90]) pico_w_mounts();
      // Servo screw bosses, rising from the floor at the shaft axis
      translate([servo_x, servo_y, wall])
        servo_mounts();
    }

    // servo pocket at the axis (shaft down through the bottom); lifted by
    // servo_boss_h so the mounting tabs rest on the screw bosses.
    translate([servo_x, servo_y, wall + servo_boss_h + servo_body_h/2])
      sg90_cutout();

    // MOSFET floor clearance (lifted off the floor like v1)
    translate([mosfet_x, mosfet_y, wall + wall*2])
      mosfet_space();

    // LED + button on the +X right wall (pierce along X)
    translate([wall_x, led_y, body_h*0.5])
      rotate([0, 90, 0]) led_hole();
    translate([wall_x, btn_y, body_h*0.5])
      rotate([0, 90, 0]) button_hole();

    // USB on the +Y top wall (pierce along Y), at the Pico's top end
    translate([pico_x, wall_y_top, body_h*0.4])
      usb_cutout();
  }
}

module rounded_box(l, w, h, r) {
  linear_extrude(height = h, center = true)
    offset(r = r) offset(r = -r)
      square([l, w], center = true);
}
