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

// Pico W 四隅スタンドオフ。基板を pico_boss_h だけ浮かせて下側 GPIO ピンを床から
// 逃がし、四隅の φ2.1 穴へ上から M2 セルフタップで留める。中心の下穴は上面から
// pico_screw_grip 深さ。フットプリントは原点中心。
module pico_w_mounts() {
  difference() {
    for (sx = [-1, 1], sy = [-1, 1])
      translate([sx * pico_hole_dx/2, sy * pico_hole_dy/2, 0])
        cylinder(d = pico_boss_d, h = pico_boss_h);            // スタンドオフ
    // セルフタップ下穴（上面から grip 深さ。上面を確実に開けるため +0.1 突き抜け）
    for (sx = [-1, 1], sy = [-1, 1])
      translate([sx * pico_hole_dx/2, sy * pico_hole_dy/2, pico_boss_h - pico_screw_grip])
        cylinder(d = pico_screw_pilot, h = pico_screw_grip + 0.1);
  }
}

// M2 セルフタップ用ボス1本（原点基準・呼び出し側で translate）。床上面に立て、上面から
// tray_screw_pilot の袋下穴を tray_screw_grip 深さで彫る（下=ドア面を貫通しない）。
module m2_boss() {
  difference() {
    cylinder(d = tray_boss_d, h = tray_boss_h);
    translate([0, 0, tray_boss_h - tray_screw_grip])
      cylinder(d = tray_screw_pilot, h = tray_screw_grip + 0.1);
  }
}

// M2 スリーブ1個の外形（原点基準）。union 側で使い、内側は m2_sleeve_cuts() で彫る。
// ボスに被さって XY 位置決めし、天面から M2 でキャップを締める（トレイで実機検証済みの構造）。
module m2_sleeve_solid() {
  cylinder(d = tray_sleeve_od, h = tray_boss_h + tray_cap_t);
}

// M2 スリーブ1個の内側カット一式（原点基準）。difference 側で使う。
// キャップ裏はボア全径から段差なしで絞る自己サポート・ファンネル。平らな張り出し（ブリッジ）を
// 一切作らないので、床下向き印刷でもネジ穴が垂れて塞がらない（実機で塞がった対策）。throat=0.3mm。
module m2_sleeve_cuts() {
  // ボス逃げボア（下端貫通〜ボス収容, φ tray_sleeve_id 一定）
  translate([0, 0, -0.1])
    cylinder(d = tray_sleeve_id, h = tray_boss_h + 0.1);
  // 自己サポート・ファンネル（ボア全径 tray_sleeve_id → 上へ tray_screw_clear へ絞る）
  translate([0, 0, tray_boss_h - 0.01])
    cylinder(d1 = tray_sleeve_id, d2 = tray_screw_clear,
             h = tray_cap_t - tray_head_h - 0.3);
  // ネジ通し throat（ファンネル上端〜天面。頭ザグリと重ねる）
  translate([0, 0, tray_boss_h + tray_cap_t - tray_head_h - 0.3 - 0.01])
    cylinder(d = tray_screw_clear, h = tray_head_h + 0.3 + 0.2);
  // 頭ザグリ（天面から）
  translate([0, 0, tray_boss_h + tray_cap_t - tray_head_h])
    cylinder(d = tray_head_d, h = tray_head_h + 0.2);
}

// トレイを本体天面（内側）から留めるための本体側ボス。tray_fix_pts の各点に床上面
// （z=wall）から立てる。トレイのスリーブが被さり、天面から M2 セルフタップで固定する。
module tray_mount_bosses() {
  for (p = tray_fix_pts)
    translate([p[0], p[1], wall]) m2_boss();
}

// USB plug opening, centered at origin, cut along Y.
module usb_cutout() {
  c = fit_clearance;
  rotate([90, 0, 0])
    translate([0, 0, -wall*2])
      linear_extrude(height = wall*4)
        offset(r = c) square([usb_w, usb_h], center = true);
}
