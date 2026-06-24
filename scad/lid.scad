include <params.scad>

// Lid with an inner lip that slips into the body opening.
// The lid center MUST match the body center (center_x, center_y) so the lip
// seats into the body opening, which is also centered at (center_x, center_y).
module lid() {
  translate([center_x, center_y, 0]) {
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
  }
}
