include <params.scad>
use <hardware.scad>

// サーボ塔（body ボルト留めの別部品）。ペデスタル v4 で筒を撤去したため、オフセットサーボは
// この塔が担う。ローカル座標: z=0 がプレート床上面（ワールド z=wall）。組立時は
// translate([0,0,wall]) servo_tower() で置く（トレイと同じ）。
//
// トポロジ:
//   ・固定スリーブ 3 本（tower_fix_pts, ローカル z 0..tower_sleeve_top=9.8）。本体側ボスが
//     下から挿さり天面から M2 セルフタップで留める（トレイ/ペデスタルと同構造）。
//   ・コラム 3 本（各スリーブ上面 → ブリッジ下面。ローカル z tower_sleeve_top..tower_col_top）。
//     いずれも駆動ギア掃引円（軸 gear_axis_pos・r 33+1）とリング歯（原点・22.5+1）の外側に立つ。
//   ・ブリッジ＋サーボ天板（gear_axis_pos 中心。天板上面 = ワールド servo_ears_z）。ギアの上を
//     内側へ張り出し、天板下面はワールド 21.9（ギア上面 15 を 6.9mm クリア、要求 19.5 以上）。
//     シャフト穴＋耳下穴＋ sg90_cutout は旧ペデスタル天板と同一。
//
// 印刷向き: スリーブ下面（ローカル z=0）をベッドに接地する「基部下向き」。スリーブのファンネルは
//   この向き（ボスが下・天面が上）で自己サポートになる設計（トレイで実機検証済み）。コラムは
//   鉛直プリズムで自立、ブリッジ＋天板の張り出し下面（ローカル z≈16..19.5）はコラム頂から
//   hull で斜めに繋いで 45°以内の傾斜面にし、可能な範囲で自己サポートにする。残る天板中央の
//   張り出しはスライサのサポートで支える（許容）。
module servo_tower() {
  c = fit_clearance;
  gp = gear_axis_pos;
  difference() {
    union() {
      // --- 固定スリーブ 3 本 ---
      for (p = tower_fix_pts)
        translate([p[0], p[1], 0]) m2_sleeve_solid();
      // --- コラム 3 本（鉛直プリズム。スリーブ上面 → コラム頂）。r39 でギア掃引円 r34 の外に立つ ---
      for (p = tower_fix_pts)
        translate([p[0], p[1], tower_sleeve_top - 0.1])
          cylinder(d = tower_col_d, h = tower_col_top - (tower_sleeve_top - 0.1));
      // --- ブリッジ帯（ローカル tower_bridge_z0..tower_col_top、ワールド >= 19.5 でギア上）。
      //     各コラム頂の円と天板中心の円板を hull で繋ぐ横梁。この帯はギア上面 15 より上なので
      //     内側（gear_axis 中心）へ張り出してもギア掃引体をまたぐだけで触れない。 ---
      for (p = tower_fix_pts)
        hull() {
          translate([p[0], p[1], tower_bridge_z0])
            cylinder(d = tower_col_d, h = tower_col_top - tower_bridge_z0);
          translate([gp[0], gp[1], tower_bridge_z0])
            cylinder(r = tower_plate_r, h = tower_col_top - tower_bridge_z0);
        }
      // --- サーボ天板（gear_axis_pos 中心・厚 servo_plate_t、上面ローカル tower_top_local） ---
      translate([gp[0], gp[1], tower_top_local - servo_plate_t])
        linear_extrude(height = servo_plate_t)
          difference() {
            circle(r = tower_plate_r);
            circle(d = servo_shaft_d + 2*c);
            for (sx = [-1, 1])
              translate([servo_shaft_offset + sx * servo_screw_span/2, 0])
                circle(d = servo_screw_pilot);
          }
    }
    // サーボポケット（gear_axis_pos の天板に耳が載る）
    translate([gp[0], gp[1], tower_top_local + servo_body_h/2])
      sg90_cutout();
    // スリーブの内側カット
    for (p = tower_fix_pts)
      translate([p[0], p[1], 0]) m2_sleeve_cuts();
    // シャフト穴＋耳下穴はブリッジ実体まで貫通させる（天板下にブリッジ材料が来るため）。
    // ブリッジ下面 tower_bridge_z0 から天板上面 tower_top_local まで貫く。
    translate([gp[0], gp[1], tower_bridge_z0 - 0.1]) {
      h = tower_top_local - tower_bridge_z0 + 0.2;
      cylinder(d = servo_shaft_d + 2*c, h = h);
      for (sx = [-1, 1])
        translate([servo_shaft_offset + sx * servo_screw_span/2, 0])
          cylinder(d = servo_screw_pilot, h = h);
    }
  }
}

// standalone render target (ignored by `use <servo_tower.scad>`)
servo_tower();
