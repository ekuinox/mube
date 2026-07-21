// M2 セルフタッピング下穴の印刷ゲージ。
// 設計径 1.8〜2.6mm（0.2 刻み）の貫通穴を servo_plate_t 厚の板に並べる。
// 印刷して M2 を順にねじ込み、「しっかり効くが割れない」穴の設計値を
// servo_screw_pilot に採用する（プリンタの小径穴収縮を実測で補正する）。
// 小径側の端は角を落としてあるので、面取り側が 1.8mm。
// 印刷向きは本番同等（板をベッドに水平、穴は縦穴）。

include <params.scad>

gauge_ds    = [1.8, 2.0, 2.2, 2.4, 2.6]; // 穴の設計径。面取り角に近い方から
gauge_pitch = 9;                          // 穴の中心間隔
gauge_w     = 12;                         // 板の幅
gauge_chamfer = 3;                        // 小径側マーカーの角落とし

len_x = gauge_pitch * len(gauge_ds);

linear_extrude(height = servo_plate_t)
  difference() {
    polygon([
      [gauge_chamfer, 0], [len_x, 0], [len_x, gauge_w],
      [0, gauge_w], [0, gauge_chamfer],
    ]);
    for (i = [0 : len(gauge_ds) - 1])
      translate([gauge_pitch * (i + 0.5), gauge_w / 2])
        circle(d = gauge_ds[i]);
    // 各穴の下に設計径×10 本…は多すぎるので、穴数ぶんの刻みノッチ
    // （左から i+1 個）で順番を機械的に判別できるようにする
    for (i = [0 : len(gauge_ds) - 1], t = [0 : i])
      translate([gauge_pitch * (i + 0.5) + (t - i / 2) * 1.6, 0])
        circle(d = 0.8, $fn = 16);
  }
