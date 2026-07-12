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

// Four Pico W rest bosses, each with a locating pin that enters the Pico's φ2.1
// mounting hole (no screw — a fastener here would hit the pin-header plastic).
// Footprint centered at origin.
module pico_w_mounts() {
  for (sx = [-1, 1], sy = [-1, 1])
    translate([sx * pico_hole_dx/2, sy * pico_hole_dy/2, 0]) {
      cylinder(d = pico_boss_d, h = pico_boss_h);              // rest shoulder
      cylinder(d = pico_pin_d, h = pico_boss_h + pico_pin_h);  // locating pin
    }
}

// トレイを本体裏から留めるための床カット：シャンク貫通穴＋裏面の皿ザグリ。
// 位置はトレイ固定ポスト tray_fix_pts に一致（ワールド座標, 床の z 原点=0）。
module tray_mount_cuts() {
  for (p = tray_fix_pts)
    translate([p[0], p[1], 0]) {
      // シャンクは床を貫通
      translate([0, 0, -0.1])
        cylinder(d = tray_screw_clear, h = wall + 0.2);
      // 皿頭のザグリ（裏面 z=0 側から）
      translate([0, 0, -0.1])
        cylinder(d = tray_head_d, h = tray_head_h + 0.1);
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
