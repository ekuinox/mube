include <params.scad>

// Lid with an inner lip that slips into the body opening.
// LED and button holes are on the lid (above the Pico, between pin header rows).
module lid() {
  pico_gap = max(6, rosette_d/2 - servo_body_w/2 + 2,
                rosette_d/2 + uboard_l/2 - pico_l/2 - servo_body_w/2 + 2);
  pico_y = servo_body_w/2 + pico_gap + pico_l/2;

  led_x = 0;
  btn_x = 0;
  led_y = pico_y - led_btn_spacing/2;
  btn_y = pico_y + led_btn_spacing/2;

  translate([center_x, center_y, 0]) {
    difference() {
      union() {
        // top plate
        linear_extrude(height = wall)
          offset(r = box_corner_r) offset(r = -box_corner_r)
            square([body_l, body_w], center = true);
        // inner lip
        translate([0, 0, -lid_lip_h])
          linear_extrude(height = lid_lip_h)
            difference() {
              square([inner_l - fit_clearance, inner_w - fit_clearance], center = true);
              square([inner_l - 2*wall, inner_w - 2*wall], center = true);
            }
      }
      // LED hole (pierce through lid along Z)
      translate([led_x - center_x, led_y - center_y, -0.1])
        cylinder(d = led_hole_d, h = wall + 0.2);
      // Button hole
      translate([btn_x - center_x, btn_y - center_y, -0.1])
        cylinder(d = button_hole_d, h = wall + 0.2);
    }
  }
}
