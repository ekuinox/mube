include <params.scad>

// Lid with an inner lip that slips into the body opening.
module lid() {
  lip_h = 4;
  union() {
    // top plate
    linear_extrude(height = wall)
      offset(r = 2) offset(r = -2)
        square([body_l, body_w], center = true);
    // inner lip
    translate([0, 0, -lip_h])
      linear_extrude(height = lip_h)
        difference() {
          square([inner_l - fit_clearance, inner_w - fit_clearance], center = true);
          square([inner_l - 2*wall, inner_w - 2*wall], center = true);
        }
  }
}
