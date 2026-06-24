include <params.scad>
use <hardware.scad>
use <mount_plate.scad>

// Servo and Pico sit SIDE BY SIDE along the WIDTH (Y axis) — matching the
// inner_w derivation: inner_w = servo_body_w + pico_w + 8.
// Servo is centered in X on the -Y half; Pico on the +Y half.
// LED/button on the +Y front wall (body_w/2). USB on the +X end wall (Pico's USB end).
module body() {
  // Both components centered in X.
  servo_x = 0;
  servo_y = -inner_w/4;  // -Y half

  pico_x  = 0;
  pico_y  = +inner_w/4;  // +Y half

  // LED and button are on the +Y wall, centered around pico_x ± led_btn_spacing/2.
  led_x    = pico_x - led_btn_spacing/2;
  btn_x    = pico_x + led_btn_spacing/2;

  // MOSFET subtraction: centered in X (between pico bosses at ±23.5), on the
  // +Y (Pico) side at floor level — safe from servo pocket (different Y half)
  // and clear of pico bosses (mosfet X extent ±8.4 < boss X at ±21.25).
  mosfet_x = 0;
  mosfet_y = pico_y;

  difference() {
    union() {
      // outer shell (open top)
      difference() {
        translate([0, 0, body_h/2])
          rounded_box(body_l, body_w, body_h, box_corner_r);
        translate([0, 0, body_h/2 + wall])
          rounded_box(inner_l, inner_w, body_h,
                      box_corner_r - wall > 0 ? box_corner_r - wall : 0.5);
      }
      // bottom mount face
      mount_plate();
      // Pico standoffs (footprint centered at (pico_x, pico_y)).
      // Sunk to wall*0.5 so the boss base overlaps the floor (z=0..wall) by
      // wall*0.5, fusing them into one solid. The pilot holes start at
      // wall*0.5 - 0.1 > 0, so they do not breach the bottom face.
      translate([pico_x, pico_y, wall*0.5])
        pico_w_mounts();
    }

    // servo pocket (shaft down through bottom)
    translate([servo_x, servo_y, wall + servo_body_h/2])
      sg90_cutout();

    // MOSFET floor clearance
    translate([mosfet_x, mosfet_y, wall + wall*2])
      mosfet_space();

    // front-wall LED + button (+Y wall)
    translate([led_x, body_w/2, body_h*0.5])
      rotate([90, 0, 0]) led_hole();
    translate([btn_x, body_w/2, body_h*0.5])
      rotate([90, 0, 0]) button_hole();

    // USB on the +X end wall (Pico's USB end), aligned to the Pico in Y
    translate([body_l/2, pico_y, body_h*0.4])
      rotate([0, 0, 90])
        usb_cutout();
  }
}

module rounded_box(l, w, h, r) {
  linear_extrude(height = h, center = true)
    offset(r = r) offset(r = -r)
      square([l, w], center = true);
}
