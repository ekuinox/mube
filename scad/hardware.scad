include <params.scad>

// SG90 body + mounting tabs + shaft clearance. Shaft axis = Z.
// The real SG90's output shaft is offset from the body center, so the body
// and tabs shift +X by servo_shaft_offset to keep the shaft on the origin.
module sg90_cutout() {
  c = fit_clearance;
  union() {
    // body
    translate([servo_shaft_offset, 0, 0])
      cube([servo_body_l + 2*c, servo_body_w + 2*c, servo_body_h + 2*c], center = true);
    // mounting tabs (wider in length) — at the shaft/floor end, matching the
    // real SG90 where the tabs sit on the output-shaft side.
    translate([servo_shaft_offset, 0, -(servo_body_h/2 - servo_tab_h/2)])
      cube([servo_tab_l + 2*c, servo_body_w + 2*c, servo_tab_h + 2*c], center = true);
    // case + gear head protruding BELOW the tab plane (実測: ケース面まで 4mm、
    // ギアヘッドの出っ張りまで計 8mm)。footprint はケースと同じで下へ抜ける。
    // 他のカットと同様 +2c で隣接カットに重ねるため、タブ面より c 上まで食い込む
    // （天板上面に 0.4mm の段差ができるが、耳が載るのは footprint の外なので影響なし）
    translate([servo_shaft_offset, 0, -(servo_body_h/2 + servo_head_h/2)])
      cube([servo_body_l + 2*c, servo_body_w + 2*c, servo_head_h + 2*c], center = true);
    // output shaft / horn clearance through the bottom face
    translate([0, 0, -servo_body_h])
      cylinder(d = servo_shaft_d + 2*c, h = servo_body_h, center = false);
  }
}

// Four Pico W standoff bosses with pilot holes. Footprint centered at origin.
module pico_w_mounts() {
  for (sx = [-1, 1], sy = [-1, 1])
    translate([sx * pico_hole_dx/2, sy * pico_hole_dy/2, 0])
      difference() {
        cylinder(d = pico_boss_d, h = pico_boss_h);
        translate([0, 0, -0.1])
          cylinder(d = pico_hole_d, h = pico_boss_h + 0.2);
      }
}

// Four M2 self-tap bosses on the body floor that the tray screws into.
// Positions match the tray's tray_screw_span_* pattern; centered at origin.
module tray_mounts() {
  for (sx = [-1, 1], sy = [-1, 1])
    translate([sx * tray_screw_span_w/2, sy * tray_screw_span_l/2, 0])
      difference() {
        cylinder(d = tray_post_d, h = pico_boss_h);
        translate([0, 0, -0.1])
          cylinder(d = tray_screw_pilot, h = pico_boss_h + 0.2);
      }
}

// USB plug opening, centered at origin, cut along Y.
module usb_cutout() {
  c = fit_clearance;
  rotate([90, 0, 0])
    translate([0, 0, -wall*2])
      linear_extrude(height = wall*4)
        offset(r = c) square([usb_w, usb_h], center = true);
}
