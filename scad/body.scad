include <params.scad>
use <hardware.scad>

// Origin = thumb-turn / servo axis (center of the door rosette).
// オープンベースプレート: ドアに両面テープで貼る1枚板。外周壁・蓋・USB 開口なし。
// ペデスタル（pedestal.scad）とトレイ（tray.scad）は天面から M2 でボルトオンする。
// 剛性は使用中はドアが担い、手持ち時のリブは Task 4 で追加。
module body() {
  c = fit_clearance;
  difference() {
    union() {
      // 床プレート（角R2。旧・箱の床と同じ footprint）
      translate([center_x, center_y, 0])
        linear_extrude(height = wall)
          plate_outline_2d();
      // ペデスタル受けカーブ（ローブ通過の切り欠き＝回り止め）
      pedestal_curb();
      // 固定ボス（トレイ4＋ペデスタル4、天面 M2 留め）
      tray_mount_bosses();
      ped_mount_bosses();
    }
    // 中央ロゼット開口（ドア側のサムターン座金を通す）
    translate([0, 0, -0.1])
      cylinder(d = rosette_d + c, h = wall + 0.2);
  }
}

// プレート外形 2D（原点基準・中心合わせは呼び出し側の translate で行う）
module plate_outline_2d() {
  offset(r = 2) offset(r = -2)
    square([body_l, body_w], center = true);
}

// 受けカーブ: フランジ基礎円（φ ped_base_d）を囲む土手リング。ped_fix_angles の各角度に
// ローブ通過の切り欠き（幅 = ローブ幅 + 両側 pedestal_fit）。切り欠き側面がローブと噛んで
// サーボ反力トルクの回り止めになる。プレートは薄く掘れないので「ポケット」ではなく土手で受ける。
module pedestal_curb() {
  translate([0, 0, wall])
    linear_extrude(height = ped_curb_h)
      difference() {
        circle(r = ped_curb_ro);
        circle(r = ped_curb_ri);
        for (a = ped_fix_angles)
          rotate([0, 0, a])
            translate([(ped_curb_ri + ped_curb_ro)/2, 0])
              square([ped_curb_wt*2 + 2, ped_lobe_w + 2*pedestal_fit], center = true);
      }
}
