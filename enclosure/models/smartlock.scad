include <params.scad>
use <body.scad>
use <pedestal.scad>
use <servo_tower.scad>
use <gears.scad>
use <tray.scad>

// Select with: openscad -D part="body" ...
part = "assembly";
// exploded=0: assembled, exploded=1: exploded view
exploded = 1;

exp = exploded ? 1 : 0;

if (part == "body") body();
else if (part == "tray") tray();
else if (part == "pedestal") pedestal();
// サーボ塔（body ボルト留め）。印刷向き: スリーブ下面（ローカル z=0）をベッドに接地する基部下向き。
else if (part == "servo_tower") servo_tower();
// リングギア（従動）。印刷向き: 歯付き盤の上面（ワールド z=15）をベッドに伏せ、
// スカート・フォーク爪を上向きに立てる（盤下面から爪先まで平坦面が無いためこの向きが安定）。
else if (part == "gear_ring")
  translate([0, 0, ring_z0 + gear_t]) rotate([180, 0, 0]) ring_gear();
// 駆動ギア。印刷向き: ハブボス下面（ローカル z=−drive_hub_h）をベッドに接地。
// 歯リング下面（ローカル z=0、ワールド換算で盤下）が z=drive_hub_h より上に浮くため、
// 歯リングのオーバーハングはスライサのサポートで支える（許容・要サポート）。
else if (part == "gear_drive")
  translate([0, 0, drive_hub_h]) drive_gear();
// 噛み合いクーポン: 両ギアの歯帯だけを 5mm 厚スライスで抜き出し、軸間距離で並べて
// 平置きする（歯当たり・バックラッシュ実測用）。リング歯帯はワールド z10..15 を切り出して
// ベッドへ落とし、駆動歯帯はローカル z0..5 をそのまま使う。駆動側は半歯位相 rotate(180/gear_z_drive)。
else if (part == "gear_mesh_coupon") {
  intersection() {
    translate([0, 0, -ring_z0]) ring_gear();
    cylinder(r = 60, h = gear_t);
  }
  translate([gear_axis_dist, 0, 0]) rotate(180/gear_z_drive)
    intersection() { drive_gear(); cylinder(r = 60, h = gear_t); }
}
// トレイの +X/+Y 隅（右固定スリーブ＋BB ポケット角）を切り出したクーポン
// （固定スリーブのネジ効き・ポケット壁の勘合確認用）
else if (part == "tray_coupon")
  intersection() {
    tray();
    translate([pocket_outer_right - 8, pocket_outer_top - 40, -1])
      cube([tray_fix_x_right + tray_sleeve_od/2 + 3 - (pocket_outer_right - 8),
            40 + 3, tray_boss_h + tray_cap_t + bb_pocket_wall_h + 3]);
  }
// 本体ボス1本＋トレイスリーブ1個を並べた嵌合クーポン（横嵌め boss_fit・効き・クランプ確認用）。
// 右下の固定点を本物の body/tray からそのまま切り出す。両方とも床下面 z=0 がベッド接地。
else if (part == "tray_mount_coupon") {
  cx = tray_fix_x_right;
  cy = tray_fix_y_lo;
  hw = tray_sleeve_od/2 + 3;   // 切り出し半幅（隣のポケット縁/壁も少し含む）
  // 本体ボス側（床パッチ＋ボス1本）
  intersection() {
    body();
    translate([cx, cy, (wall + tray_boss_h + 2)/2 - 0.1])
      cube([2*hw, 2*hw, wall + tray_boss_h + 2], center = true);
  }
  // トレイスリーブ側（床パッチ＋スリーブ1個）。印刷用に +X へ退避。
  translate([2*hw + 8, 0, 0])
    intersection() {
      tray();
      translate([cx, cy, (tray_boss_h + tray_cap_t + 2)/2 - 0.1])
        cube([2*hw, 2*hw, tray_boss_h + tray_cap_t + 2], center = true);
    }
}
// ペデスタル固定の嵌合クーポン（フランジ⇔受けカーブの横嵌め pedestal_fit・ローブ⇔切り欠きの
// 噛み・M2 の効き・面一沈み確認用）。45° の固定点まわりを本物の body/pedestal から切り出す。
// 両方とも底面 z=0 がベッド接地。ペデスタル側は印刷用に +X へ退避。
else if (part == "ped_mount_coupon") {
  cp = ped_fix_pts[0];   // 45° の固定点 (≈21.2, 21.2)
  hw = 14;               // 切り出し半幅（カーブ切り欠き・ローブ・ボス・カーブ本体を含む）
  // プレート側（床パッチ＋ボス1本＋カーブの切り欠き部分）
  intersection() {
    body();
    translate([cp[0], cp[1], (wall + tray_boss_h + 2)/2 - 0.1])
      cube([2*hw, 2*hw, wall + tray_boss_h + 2], center = true);
  }
  // ペデスタル側（フランジローブ＋スリーブ1個＋筒壁の一部）
  translate([2*hw + 8, 0, 0])
    intersection() {
      pedestal();
      translate([cp[0], cp[1], (tray_boss_h + tray_cap_t + 2)/2 - 0.1])
        cube([2*hw, 2*hw, tray_boss_h + tray_cap_t + 2], center = true);
    }
}
// 床フットプリントのみ切り出した薄型クーポン（ロゼット嵌合＋ドア左/下クリアランス確認用）。
// 台座は別部品化済みのため、ここに写るのは床＋受けカーブ(2.4mm)＋ボス根元まで。
// ロゼットの出っ張りが中央開口(Ø45.4)へ逃げるかを実ドアで当てて確認する。
else if (part == "floor_coupon")
  intersection() {
    body();
    linear_extrude(height = wall + 8)
      square([300, 300], center = true);
  }
else if (part == "asm_body") color("SteelBlue") body();
// リングギア（ワールド座標そのまま）。分解ビューは -Z へ退避。
else if (part == "asm_gear_ring")
  color("SandyBrown")
    translate([0, 0, exp * -12]) ring_gear();
// 駆動ギア（軸オフセット位置・ローカル z=0 をワールド ring_z0 に合わせる）。噛み合い位相で回す。分解ビューは +Z へ退避。
else if (part == "asm_gear_drive")
  color("Orange")
    translate([gear_axis_pos[0], gear_axis_pos[1], ring_z0 + exp * 12])
      rotate(gear_drive_phase) drive_gear();
else if (part == "asm_tray")
  color("Plum")
    translate([0, 0, wall + exp * 10]) tray();
else if (part == "asm_pedestal")
  color("Khaki")
    translate([0, 0, wall + exp * 8]) pedestal();
// サーボ塔（組立位置 z=wall。分解ビューは +Z へ退避）
else if (part == "asm_servo_tower")
  color("MediumSeaGreen")
    translate([0, 0, wall + exp * 16]) servo_tower();
else {
  // full assembly
  color("SteelBlue") body();

  color("Khaki")
    translate([0, 0, wall + exp * 8]) pedestal();

  color("MediumSeaGreen")
    translate([0, 0, wall + exp * 16]) servo_tower();

  // リングギア（ワールド座標）＋駆動ギア（軸オフセット位置・z=ring_z0・噛み合い位相）
  color("SandyBrown")
    translate([0, 0, exp * -12]) ring_gear();
  color("Orange")
    translate([gear_axis_pos[0], gear_axis_pos[1], ring_z0 + exp * 12])
      rotate(gear_drive_phase) drive_gear();

  color("Plum")
    translate([0, 0, wall + exp * 10]) tray();
}
