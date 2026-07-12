include <params.scad>
use <hardware.scad>

// 電子部品トレイ（ワールド座標＝軸原点フレームで構築）。
// Pico を +Y 天井壁寄りに短ボスで載せ、その右へブレッドボードを浅い囲い壁ポケット
// で落とし込む。四隅付近の固定ポスト4本で本体床へ M2 セルフタップ留め。Pico は
// 位置決めピン（ボス）＋コーナー爪で押さえる。床は translate([0,0,wall]) で本体床上へ。
module tray() {
  difference() {
    union() {
      // 床プレート（Pico・ポケット・固定ポストを内包）
      translate([(tray_x0 + tray_x1)/2, (tray_y0 + tray_y1)/2, tray_t/2])
        cube([tray_x1 - tray_x0, tray_y1 - tray_y0, tray_t], center = true);

      // Pico 短ボス＋位置決めピン（長軸 Y ＝ 90 度回転）を Pico 中心へ
      translate([pico_x, pico_y, tray_t])
        rotate([0, 0, 90]) pico_w_mounts();

      // BB 浅い囲い壁ポケット（外形 - 内形 を壁高ぶん押し出し）
      translate([bb_off_x, bb_off_y, tray_t])
        linear_extrude(height = bb_pocket_wall_h)
          difference() {
            square([bb_w + 2*(bb_clearance + bb_pocket_wt),
                    bb_l + 2*(bb_clearance + bb_pocket_wt)], center = true);
            square([bb_w + 2*bb_clearance, bb_l + 2*bb_clearance], center = true);
          }

      // 固定ポスト4本（床上に立てる）
      for (p = tray_fix_pts)
        translate([p[0], p[1], tray_t])
          cylinder(d = tray_fix_d, h = tray_fix_h);

      // Pico コーナー爪（Pico の -X/+X 長辺中央を上から掴む L 字）
      pico_clip(pico_x - pico_w/2, pico_y,  1);   // -X 側（フックは +X 向き）
      pico_clip(pico_x + pico_w/2, pico_y, -1);   // +X 側（フックは -X 向き）
    }

    // 固定ポスト下穴（トレイ裏 z0 から grip 深さ。床を貫通してポストへ効く）
    for (p = tray_fix_pts)
      translate([p[0], p[1], -0.1])
        cylinder(d = tray_screw_pilot, h = tray_screw_grip + 0.1);

    // USB 向きマーカー（Pico の +Y 端側の床に凹み矢印）
    tray_usb_marker();
  }
}

// Pico を上から押さえるコーナー爪。edge_x = Pico の長辺 x、dir = フックが伸びる向き
// (+1 で +X, -1 で -X)。柱は Pico 上面まで、先端に pico_clip_hook の張り出し。
module pico_clip(edge_x, edge_y, dir) {
  // 柱：Pico の外側すぐに立てる（fit_clearance ぶん離す）
  post_x = edge_x + dir * (fit_clearance + pico_clip_t/2);
  translate([post_x, edge_y, tray_t]) {
    // 縦柱
    translate([0, 0, pico_clip_h/2])
      cube([pico_clip_t, pico_clip_w, pico_clip_h], center = true);
    // 先端フック（Pico 上面高さで内側へ張り出す）
    translate([-dir * (pico_clip_t/2 + pico_clip_hook/2), 0, pico_clip_h])
      cube([pico_clip_hook + pico_clip_t, pico_clip_w, 1.2], center = true);
  }
}

// Pico の +Y（USB）端側を指す凹み矢印。USB 端はこちら＝本体 +Y 壁の開口に合わせる。
module tray_usb_marker() {
  depth = 0.6;
  translate([pico_x, pico_y + pico_l/2 - 6, tray_t - depth])
    linear_extrude(height = depth + 0.1)
      polygon(points = [[-2.5, 0], [2.5, 0], [0, 4.5]]);
}

// standalone render target (ignored by `use <tray.scad>`)
tray();
