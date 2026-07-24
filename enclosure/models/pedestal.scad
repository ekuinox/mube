include <params.scad>
use <hardware.scad>

// ボルトオン・ペデスタル v3（ギアデッキ）。ローカル座標: z=0 がフランジ底面。組立時は
// プレート床上面 z=wall に載せる（ローカル z = ワールド z − wall）。
// 底フランジ（基礎円＋対角4ローブ）＋スリーブ4点は現行と不変のボルトオン・インターフェース。
//
// v3 の 3 要素:
//   受けカラー: 内フランジ棚（ローカル ped_shelf_z0..collar_z0−wall）からカラー環
//     （ワールド collar_z0..ped_collar_z1 = 6.4..9.8、内 ped_collar_ri / 外 ped_collar_ro）が
//     立ち上がる。リングギアのスカート（外径 36）を外側から抱き、スカート外面が回転摺動する。
//     棚がスカート下端の軸方向下荷重を受ける。当初の内側カラー案はフォーク爪（外半径 16.9）と
//     体積干渉するため外側軸受けに変更した（params.scad の DEVIATION 参照）。
//   噛み合い窓: 筒壁（内 ped_cyl_ri=23.2 / 外 ped_cyl_ro=25.6）を gear_dir_deg(−30°)
//     中心に半角 ped_window_ang 切り欠き、ワールド z 9..16 で駆動歯を通す。
//   オフセットサーボ天板: gear_axis_pos 中心・厚 servo_plate_t、上面ワールド servo_ears_z、
//     シャフト穴＋耳下穴。筒からの持ち出し梁で支持する。
//
// リングギアの組み込み手順: リングギア（歯先半径 22.5）は筒（内 23.2、逃げ 0.7）の上から
// ドア側へ落とし込む。スカート（外径 36）は受けカラーの内側（内径 ≈36.3）へ入り、外面が
// カラー内面を摺動する。軸方向下向きは棚（スカート下端の床）が受け、上向きは初版では自重＋
// 駆動ギアの噛み合いのみ（浮き対策のバヨネットタブはクーポン後に検討）。
module pedestal() {
  c = fit_clearance;
  top_local = servo_ears_z - wall;  // サーボ天板上面（ローカル ≈ 23）
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
      // --- 筒（内半径をリング歯先逃げまで拡大） ---
      linear_extrude(height = top_local)
        difference() { circle(r = ped_cyl_ro); circle(r = ped_cyl_ri); }
      // --- 内フランジ棚（リングギアスカート下端の軸方向下荷重を受ける床） ---
      //     外半径は筒壁へ 1mm 食い込ませて確実に融合させる（筒内 23.2 < 24.2 < 筒外 25.6）。
      //     内半径 ped_shelf_ri=16.4（スカート内径）まで詰めてスカート下端を広く受ける。
      //     棚は z2..4（ローカル）＝ワールド 4.4..6.4 で、フォーク爪の掃引には来ない（爪の
      //     r16.9 到達は z10..15 の盤側のみ。棚高では爪は r<=16.4 の内側にしか無い）。
      translate([0, 0, ped_shelf_z0])
        linear_extrude(height = (ped_shelf_z1 - wall) - ped_shelf_z0)
          difference() { circle(r = ped_cyl_ri + 1); circle(r = ped_shelf_ri); }
      // --- 受けカラー（リングギアスカートを外側から抱く軸受け環） ---
      //     スカート外面 r18 が内面 ped_collar_ri=18.15 を摺動。上端はワールド ring_z0−0.2 で
      //     歯付き盤（z10..15）を避け、下端は棚上面（ワールド ped_shelf_z1=6.2）に載せて融合。
      translate([0, 0, ped_shelf_z1 - wall])
        linear_extrude(height = ped_collar_z1 - ped_shelf_z1)
          difference() { circle(r = ped_collar_ro); circle(r = ped_collar_ri); }
      // --- サーボ天板（オフセット位置）＋持ち出し梁 ---
      translate([gear_axis_pos[0], gear_axis_pos[1], top_local - servo_plate_t])
        linear_extrude(height = servo_plate_t)
          difference() {
            circle(r = ped_plate_r);
            circle(d = servo_shaft_d + 2*c);
            for (sx = [-1, 1])
              translate([servo_shaft_offset + sx * servo_screw_span/2, 0])
                circle(d = servo_screw_pilot);
          }
      // 梁: 筒の上端帯からサーボ天板まで（セパレーション反力方向。歯帯より上を通す）
      translate([0, 0, top_local - servo_plate_t - 4])
        linear_extrude(height = servo_plate_t + 4)
          intersection() {
            hull() {
              circle(r = ped_cyl_ro);
              translate(gear_axis_pos) circle(r = ped_plate_r);
            }
            rotate(gear_dir_deg) translate([0, -ped_arm_w/2]) square([100, ped_arm_w]);
          }
      // 固定スリーブ（現行と同一）
      for (p = ped_fix_pts)
        translate([p[0], p[1], 0]) m2_sleeve_solid();
    }
    // サーボポケット（オフセット位置の天板に耳が載る）
    translate([gear_axis_pos[0], gear_axis_pos[1], top_local + servo_body_h/2])
      sg90_cutout();
    // 噛み合い窓（gear_dir_deg 方向の筒壁を歯帯の高さだけ切り欠く）
    rotate(gear_dir_deg)
      translate([0, 0, ped_window_z0])
        linear_extrude(height = ped_window_z1 - ped_window_z0)
          polygon([[0, 0],
                   [60 * cos(ped_window_ang),  60 * sin(ped_window_ang)],
                   [60, 0],
                   [60 * cos(ped_window_ang), -60 * sin(ped_window_ang)]]);
    // 中央ロゼット通し（現行と同一）
    translate([0, 0, -0.1])
      cylinder(d = rosette_d + c, h = ped_flange_t + 0.2);
    // スリーブの内側カット（現行と同一）
    for (p = ped_fix_pts)
      translate([p[0], p[1], 0]) m2_sleeve_cuts();
  }
}

// standalone render target (ignored by `use <pedestal.scad>`)
pedestal();
