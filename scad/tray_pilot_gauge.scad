// トレイ・ポストの M2 自己タップ下穴ゲージ（実際のポスト条件を再現）。
// tray_fix_d 径・tray_fix_h 高さのポストを並べ、各ポスト上面から
// tray_screw_grip 深さの袋下穴を設計径 1.7〜2.2mm（0.1刻み）で開ける。
// 印刷して M2 を上からねじ込み、「しっかり効くが割れない」設計値を
// tray_screw_pilot に採用する。
//
// 平板ゲージ(pilot_gauge.scad)ではなくポスト形状にしたのは、深い縦穴が
// 平板の貫通穴と収縮量が違うため（実機で平板由来の 2.2 がポストでは緩かった）。
// 印刷向き：ベースをベッドに置きポストを立てる（本番同等）。下穴は上からの縦穴。
// 識別：小径側の角を落としてある（面取り側が最小径 1.7）。各ポスト手前の刻み
// ノッチが左から i+1 個 = 何番目か（1個=1.7, 2個=1.8, ...）。

include <params.scad>

gauge_ds    = [1.7, 1.8, 1.9, 2.0, 2.1, 2.2]; // 下穴 設計径（小さい順）
gauge_pitch = 10;                              // ポスト中心間隔
base_t      = 2;                               // ベース板厚
base_w      = 12;                              // ベース奥行き
chamfer     = 3;                               // 小径側マーカーの角落とし

len_x = gauge_pitch * len(gauge_ds);

// ベース板（小径側の角を落として向きの目印に）＋識別ノッチ
linear_extrude(height = base_t)
  difference() {
    polygon([
      [chamfer, 0], [len_x, 0], [len_x, base_w],
      [0, base_w], [0, chamfer],
    ]);
    for (i = [0 : len(gauge_ds) - 1], t = [0 : i])
      translate([gauge_pitch * (i + 0.5) + (t - i / 2) * 1.6, 0])
        circle(d = 0.8, $fn = 16);
  }

// ポスト＋上面からの袋下穴（本番トレイと同じ径・高さ・下穴深さ）
for (i = [0 : len(gauge_ds) - 1])
  translate([gauge_pitch * (i + 0.5), base_w / 2, 0])
    difference() {
      cylinder(d = tray_fix_d, h = base_t + tray_fix_h);
      translate([0, 0, base_t + tray_fix_h - tray_screw_grip])
        cylinder(d = gauge_ds[i], h = tray_screw_grip + 0.1);
    }
