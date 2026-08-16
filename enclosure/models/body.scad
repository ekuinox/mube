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
      // 上面リブ（カバー耳4点周りを逃がした外周リブ。plate_ribs() 参照）
      plate_ribs();
      // ペデスタル受けカーブ（ローブ通過の切り欠き＝回り止め）
      pedestal_curb();
      // 固定ボス（トレイ4＋ペデスタル4＋カバー4、天面 M2 留め）
      tray_mount_bosses();
      ped_mount_bosses();
      cover_mount_bosses();
    }
    // 中央ロゼット開口（ドア側のサムターン座金を通す）
    translate([0, 0, -0.1])
      cylinder(d = rosette_d + c, h = wall + 0.2);
  }
}

// プレート外形 2D（プレート中心基準・中心合わせは呼び出し側の translate で行う）。
// 矩形本体＋四隅のカバー固定ラグを角R2 で融合する。
module plate_outline_2d() {
  offset(r = 2) offset(r = -2)
    union() {
      square([body_l, body_w], center = true);
      for (p = cover_ear_pts)
        translate([p[0] - center_x, p[1] - center_y]) circle(d = plate_lug_d);
    }
}

// 上面リブ: カバー固定ボス（cover_ear_pts の4点。-Y 側の2隅＋±X 壁上の2点。Task 3 で
// +Y 側を角から壁の中点へ移した）を逃がした外周リブ（横桟は plate_rib_ys=[] で全廃済み。
// カバーの -X/+X 側壁が全幅横桟の真下を貫いてしまい座らなくなるため。剛性は M2 留めされた
// カバーが肩代わりする）。4点それぞれの逃げが辺を数 mm ずつ食うため、実体は
// 閉じた一周ではなく 4 本の独立した直線区間になる（位置決めリップとしては X・Y 両方向を
// 直線区間で拘束するので機能上は問題ない）。受けカーブ・スリーブ・ロゼット開口の周りは
// 半径 ped_curb_ro+1 で、カバー固定ボスの周りは各点 max(tray_sleeve_od+1, plate_lug_d+0.2)
// で丸ごと逃がす（開口の上をリブが橋渡しして印刷ブリッジになるのも防ぐ）。
module plate_ribs() {
  translate([0, 0, wall])
    linear_extrude(height = plate_rib_h)
      difference() {
        union() {
          // 外周リブ（プレート輪郭の内側 plate_rib_w 幅）
          translate([center_x, center_y])
            difference() {
              plate_outline_2d();
              offset(delta = -plate_rib_w) plate_outline_2d();
            }
          // 横桟（全幅。外周リブと融合する）
          for (y = plate_rib_ys)
            translate([center_x, y])
              square([body_l, plate_rib_w], center = true);
        }
        // 受けカーブ・スリーブ・中央開口まわりの逃げ
        circle(r = ped_curb_ro + 1);
        // カバー固定ボスまわりの逃げ（リブとボスの干渉を避ける）。ラグ輪郭（plate_lug_d）
        // より小さいと各点にノズル幅未満の三日月壁が残ってしまうため、ラグ径基準の
        // 逃げも下限として取る。
        for (p = cover_ear_pts)
          translate([p[0], p[1]]) circle(d = max(tray_sleeve_od + 1, plate_lug_d + 0.2));
      }
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
