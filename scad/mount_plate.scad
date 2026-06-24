include <params.scad>

// v1: flat tape face matching the body footprint.
// FUTURE (Q6): replace this module body with a brace arm / bolt-on shim
// once the door-side fixed feature is confirmed. Keep the same module name.
module mount_plate() {
  linear_extrude(height = wall)
    offset(r = 2) offset(r = -2)
      square([body_l, body_w], center = true);
}
