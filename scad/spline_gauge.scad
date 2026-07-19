// SG90 スプライン直嵌合（ホーンレス案 D）の下穴ゲージ。
// v4: burariweb の実証レシピを移植
// (https://burariweb.info/gadget/3d-printer/sg90-servo-horn-modeling.html)。
// 21 歯・穴の基準円 5.25 / 歯先内径 ~4.4・歯は 1 辺 0.51mm の二等辺三角形を
// 円形配列で 21 個並べる。歯が離散三角形（歯間に平坦部が残る）なので
// 0.4 ノズルでも 1 歯ずつスライサーに描かれやすく、著者環境では
// 「空回りせず付属ホーンと遜色なく動作」を確認済み。
// 記事の推奨に従い、辺の長さ（歯の大きさ）を 0.1 刻みで振って追い込む。
// 穴の並び（角落とし側から、ノッチ数=順番。[基準円径, 三角形の辺]）:
//   1: 5.25/辺0.41  2: 5.25/辺0.51(記事の値)  3: 5.25/辺0.61
//   4: 5.10/辺0.51  5: 5.40/辺0.51
// 圧入時は軽く回して歯の位相が合う所で押し込む。
// 印刷向きは本番同等（板をベッドに水平、穴は縦穴）。

include <params.scad>

// [基準円径(歯の根元が乗る穴径), 歯三角形の辺長]
sg_holes = [
  [5.25, 0.41],
  [5.25, 0.51],
  [5.25, 0.61],
  [5.10, 0.51],
  [5.40, 0.51],
];
sg_teeth   = 21;   // SG90 スプラインの歯数
sg_pitch   = 12;   // 穴の中心間隔
sg_w       = 14;   // 板の幅
sg_t       = 5;    // 板厚。スプラインの掛かり代（~4mm）より深め
sg_chamfer = 3;    // 小径側マーカーの角落とし
sg_lead    = 0.5;  // 入口の 45° 面取り

len_x = sg_pitch * len(sg_holes);

// 基準円 d_bore のなめらか穴の内周に、辺 s の二等辺（正）三角形の歯を
// 21 個内向きに立てる。底辺は円周上（+0.2 外側へ延長して確実に融合）、
// 頂点が内側（歯先）。歯先円径 = d_bore - 2*(s*sqrt(3)/2)
module hole_spline_2d(d_bore, s) {
  h = s * sqrt(3) / 2;
  difference() {
    circle(d = d_bore);
    for (i = [0 : sg_teeth - 1])
      rotate(360 * i / sg_teeth)
        translate([0, d_bore / 2])
          polygon([[-s / 2, 0.2], [s / 2, 0.2], [0, -h]]);
  }
}

difference() {
  linear_extrude(height = sg_t)
    difference() {
      polygon([
        [sg_chamfer, 0], [len_x, 0], [len_x, sg_w],
        [0, sg_w], [0, sg_chamfer],
      ]);
      // 穴数ぶんの刻みノッチ（左から i+1 個）で順番を判別する
      for (i = [0 : len(sg_holes) - 1], t = [0 : i])
        translate([sg_pitch * (i + 0.5) + (t - i / 2) * 1.6, 0])
          circle(d = 0.8, $fn = 16);
    }
  for (i = [0 : len(sg_holes) - 1])
    translate([sg_pitch * (i + 0.5), sg_w / 2]) {
      translate([0, 0, -0.1])
        linear_extrude(height = sg_t + 0.2)
          hole_spline_2d(sg_holes[i][0], sg_holes[i][1]);
      // 入口（上面）の 45° 面取り
      translate([0, 0, sg_t - sg_lead])
        cylinder(d1 = sg_holes[i][0], d2 = sg_holes[i][0] + 2 * sg_lead,
                 h = sg_lead + 0.1);
    }
}
