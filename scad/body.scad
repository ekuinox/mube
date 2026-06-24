include <params.scad>
use <hardware.scad>
use <mount_plate.scad>

// Servo sits on the -X half (shaft pointing down through the bottom).
// Pico sits on the +X half. LED/button on the +Y front wall. USB on the -Y wall.
module body() {
  // X position for the servo shaft / socket opening
  servo_x = -inner_l/4;
  // pico_x = 0 (centered on X) to keep standoff bosses within inner_l/2 bounds
  // (brief suggests inner_l/6, but that pushes pico_hole_dx/2 = 23.5 beyond inner_l/2 = 28.5
  // at inner_l/6 + 23.5 = 33, which is outside the shell wall)
  pico_x  = 0;

  difference() {
    union() {
      // outer shell (open top)
      difference() {
        translate([0, 0, body_h/2])
          rounded_box(body_l, body_w, body_h, 3);
        translate([0, 0, body_h/2 + wall])
          rounded_box(inner_l, inner_w, body_h, 3 - wall > 0 ? 3 - wall : 0.5);
      }
      // bottom mount face
      mount_plate();
      // Pico standoffs
      translate([pico_x, 0, wall])
        pico_w_mounts();
    }

    // servo pocket (shaft down through bottom)
    translate([servo_x, 0, wall + servo_body_h/2])
      sg90_cutout();

    // front-wall LED + button (front = +Y wall)
    translate([pico_x - 8, body_w/2, body_h*0.5])
      rotate([90, 0, 0]) led_hole();
    translate([pico_x + 8, body_w/2, body_h*0.5])
      rotate([90, 0, 0]) button_hole();

    // USB port on -Y wall near Pico
    translate([pico_x + pico_l/2 - usb_w, -body_w/2, body_h*0.4])
      usb_cutout();
  }
}

module rounded_box(l, w, h, r) {
  linear_extrude(height = h, center = true)
    offset(r = r) offset(r = -r)
      square([l, w], center = true);
}
