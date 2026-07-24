include <params.scad>
use <hardware.scad>

// ボルトオン・ペデスタル v4（ロー・ベアリング支持）。ローカル座標: z=0 がフランジ底面。組立時は
// プレート床上面 z=wall に載せる（ローカル z = ワールド z − wall）。
// 底フランジ（基礎円＋対角4ローブ）＋スリーブ4点は現行と不変のボルトオン・インターフェース。
//
// v4 で撤去したもの（v3 → v4）:
//   ・サムターンを囲う背高の筒（内 23.2 / 外 25.6、ローカル z0..23）と噛み合い窓
//   ・オフセットサーボ天板＋持ち出し梁（→ 別部品 servo_tower.scad へ分離）
// これによりサムターン周囲はオープンになり、ギアが露出する（模倣元デザインと同じ）。
//
// v4 に残す 1 要素（受けベアリング。筒ではなくフランジに直接根付かせる）:
//   受けカラー: 内フランジ棚（ローカル ped_shelf_z0..、フランジへ食い込ませて融合）から
//     カラー環（ワールド collar_z0..ped_collar_z1 = 6.4..9.8、内 ped_collar_ri / 外 ped_collar_ro）が
//     立ち上がる。リングギアのスカート（外径 36）を外側から抱き、スカート外面が回転摺動する。
//     棚がスカート下端の軸方向下荷重を受ける。カラー最上端はワールド 9.8（ローカル 7.4）で、
//     これより上には一切の材料を出さない（サムターン周囲はオープン）。
//   ノブ帯（r < 15）は空のまま（clash のノブ包絡ガードが緑であること）。
//   リングギア（歯先 22.5）は上からドア側へ落とし込む。障害物が無いので挿入は常に自由。
module pedestal() {
  c = fit_clearance;
  difference() {
    union() {
      // --- 底フランジ＋ローブ（現行と同一。ボルトオン・インターフェース不変） ---
      linear_extrude(height = ped_flange_t)
        union() {
          circle(r = rosette_d/2 + pedestal_wall_t + c);
          for (p = ped_fix_pts)
            hull() {
              translate([p[0]/2, p[1]/2]) circle(d = ped_lobe_w);
              translate([p[0],   p[1]])   circle(d = ped_lobe_w);
            }
        }
      // --- 内フランジ棚（リングギアスカート下端の軸方向下荷重を受ける床） ---
      //     筒が無くなったので外半径はカラー外周へ寄せ、ローブ基礎円の実体に根付かせる
      //     （ped_shelf_z0 = 2 < フランジ厚 2.4 なので棚下面はフランジ内部に食い込んで融合）。
      //     内半径 ped_shelf_ri=17.2（フォーク爪外半径 16.9 + 逃げ）でスカート下端を受ける。
      translate([0, 0, ped_shelf_z0])
        linear_extrude(height = (ped_shelf_z1 - wall) - ped_shelf_z0)
          difference() { circle(r = ped_shelf_ro); circle(r = ped_shelf_ri); }
      // --- 受けカラー（リングギアスカートを外側から抱く軸受け環） ---
      //     スカート外面 r18 が内面 ped_collar_ri=18.15 を摺動。上端はワールド ring_z0−0.2 で
      //     歯付き盤（z10..15）を避け、下端は棚上面（ワールド ped_shelf_z1=6.2）に載せて融合。
      translate([0, 0, ped_shelf_z1 - wall])
        linear_extrude(height = ped_collar_z1 - ped_shelf_z1)
          difference() { circle(r = ped_collar_ro); circle(r = ped_collar_ri); }
      // 固定スリーブ（現行と同一）
      for (p = ped_fix_pts)
        translate([p[0], p[1], 0]) m2_sleeve_solid();
    }
    // 中央ロゼット通し（現行と同一）
    translate([0, 0, -0.1])
      cylinder(d = rosette_d + c, h = ped_flange_t + 0.2);
    // スリーブの内側カット（現行と同一）
    for (p = ped_fix_pts)
      translate([p[0], p[1], 0]) m2_sleeve_cuts();
    // 駆動ギア歯逃がし（v3 の噛み合い窓の代替。筒は撤去したが 315° の固定スリーブ(≈21.2,−21.2)は
    // 駆動ギア歯帯(ワールド z10..15・軸 gear_axis_pos の r19..33)の真下に入り、スリーブ頂(ワールド
    // 12.2)が歯下面 10 と 2.2mm 重なる。ここだけ歯掃引円(半径 tower_gear_swept_r+逃げ)でスリーブ頂を
    // ワールド z=9.9(ローカル 7.5)まで削って歯を通す。M2 は「抜け止め専任」なので座ぐりが一部欠けても
    // 抜け止め保持は成立する（下部の袋ねじ効きは無傷）。ノブ側(原点付近)には一切掛からない。
    translate([gear_axis_pos[0], gear_axis_pos[1], (ring_z0 - wall) - 0.05 - 0.1])
      cylinder(r = tower_gear_swept_r + 0.6, h = 20);
  }
}

// standalone render target (ignored by `use <pedestal.scad>`)
pedestal();
