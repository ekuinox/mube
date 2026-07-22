// ホーン押さえスナップ爪のクーポン。
// 現行 socket のホーンバーポケット（テーパー一文字＋ハブ＋中心スタブ）を
// ミニブロック上面に複製し、バーを上から押さえる爪を付けた試験片。
// 上面の溝線 1 本 = 予圧 0.3、2 本 = 予圧 0.5。
// 印刷向きは本番同等（ポケット面を上・爪は縦）。
//
// 変遷:
// v1: バー端のナイフエッジ三角 → 返しの薄部がスライサーに消え噛まず
// v2: 垂直先端面 0.6 で噛むが上下ガタ
// v3: くさび予圧 0.15/0.30 → まだ緩い。原因はバーの「端」に爪を置いたことで、
//     端面は爪面から 0.3mm しか離れておらず、くさびの最も浅い区間にしか
//     エッジ接触しない（実効予圧が設計値の 1/3 程度＋印刷丸まりで目減り）
// v4: 爪をバーの「横」（先端付近の長辺側・計 4 本）へ移設。返し 1.2 をバーの
//     上面そのものに被せ、浅いくさび（勾配 ~0.3）でばね力を下向きの
//     押さえ付け力へ変換する。浮き方向には自己ロック気味に効く。

include <params.scad>

hs_preloads = [0.3, 0.5]; // くさび予圧（バー上面への食い込み設計値）
hs_hk       = 1.2;   // 返しの overhang（バー上面への被さり量）
hs_face     = 0.8;   // 返し先端の垂直面高さ（印刷消失防止。v3 の 0.6 から増量）
hs_tip_clear = 0.05; // 返し先端下面とバー上面のすき間
hs_claw_w   = 5;     // 爪の幅（バー長手方向）
hs_claw_t   = 1.2;   // 爪の梁厚
hs_root_z   = 1.0;   // 爪の根元高さ。ここから上が撓む
hs_block_h  = 10;    // ブロック高。ポケット床 = hs_block_h - (horn_thick + horn_clearance)
hs_bw       = 16;    // ブロック奥行き（爪の逃がし分 v3 より広め）
hs_lead     = 1.6;   // 返しの上の差し込みガイド高
hs_side     = 0.8;   // 爪の左右（X 方向）の逃がし
hs_claw_x   = 12.5;  // 爪の中心 |x|（バー先端寄り。バー幅が細く上面が広く出る位置）

pocket_d = horn_thick + horn_clearance;  // ポケット深さ 2.0
floor_z  = hs_block_h - pocket_d;        // ポケット床
lx       = 2 * (horn_arm_l + horn_clearance) + 4;  // ブロック全長（端に薄壁を残す）

// 現行 socket と同一のポケット 2D 形状（テーパー一文字バー＋ハブ円）
module horn_pocket_2d() {
  offset(r = horn_clearance)
    union() {
      polygon([
        [-horn_arm_l, -horn_arm_w_tip/2],
        [          0, -horn_arm_w_base/2],
        [ horn_arm_l, -horn_arm_w_tip/2],
        [ horn_arm_l,  horn_arm_w_tip/2],
        [          0,  horn_arm_w_base/2],
        [-horn_arm_l,  horn_arm_w_tip/2]
      ]);
      circle(d = horn_hub_d);
    }
}

// バー長手 x でのポケット半幅（バー部分のみ・クリアランス込み）
function bar_hw(x) = horn_clearance +
  (horn_arm_w_tip + (horn_arm_w_base - horn_arm_w_tip) * (1 - abs(x) / horn_arm_l)) / 2;

// +Y 側・中心 cx の押さえ爪。梁は Y 方向に撓み、返しはバー上面に被さる。
// くさび下面: 爪面側（バーの外）が低く、先端（バーの上）が高い浅い坂。
// バー上面(floor_z + horn_thick)に対し、被さり区間で preload ぶん食い込む設計。
module claw(cx, preload) {
  cy = bar_hw(cx);                          // 爪の内面 y = ポケット縁
  bar_top = floor_z + horn_thick;
  hz_lo = bar_top - preload;                // くさびの爪面側の高さ（バー上面より低い）
  wedge = preload + hs_tip_clear;           // 坂の総上がり（先端はバー上面を僅かに越える）
  translate([cx, cy, 0]) {
    // 梁（内面 y=0 ローカル、+Y へ厚み）
    translate([-hs_claw_w/2, 0, hs_root_z])
      cube([hs_claw_w, hs_claw_t, hz_lo + wedge + hs_face + hs_lead - hs_root_z]);
    // 返し（Y-Z 断面の多角形を X へ押し出し）
    translate([-hs_claw_w/2, 0, 0])
      rotate([90, 0, 90])
        linear_extrude(height = hs_claw_w)
          polygon([
            [    0, hz_lo],                          // 爪面・坂の下端
            [-hs_hk, hz_lo + wedge],                 // 先端・坂の上端（バー上面+0.05）
            [-hs_hk, hz_lo + wedge + hs_face],       // 先端の垂直面
            [    0, hz_lo + wedge + hs_face + hs_lead], // 差し込みガイド
          ]);
  }
}

module snap_block(preload, notches) {
  difference() {
    translate([-lx/2, -hs_bw/2, 0])
      cube([lx, hs_bw, hs_block_h]);
    // ポケット（上面から掘る）
    translate([0, 0, floor_z])
      linear_extrude(height = pocket_d + 0.1)
        horn_pocket_2d();
    // 爪の切り離し: 内側（返しの通り道）・左右・背面（撓みしろ 1.5）を逃がす
    for (sx = [-1, 1], sy = [0, 1])
      mirror([0, sy, 0])
        translate([sx * hs_claw_x - hs_claw_w/2 - hs_side,
                   bar_hw(hs_claw_x) - hs_hk - 0.2, hs_root_z])
          cube([hs_claw_w + 2*hs_side, hs_hk + 0.2 + hs_claw_t + 1.5, hs_block_h]);
    // 変種判別の溝線（上面左端寄り。1 本=予圧0.3 / 2 本=0.5）
    for (t = [0 : notches - 1])
      translate([-lx/2 + 3 + t * 3, -hs_bw/2 - 0.1, hs_block_h - 0.8])
        cube([1.2, hs_bw + 0.2, 0.9]);
  }
  // 爪（両先端付近の両脇・計 4 本）
  for (sx = [-1, 1], sy = [0, 1])
    mirror([0, sy, 0])
      claw(sx * hs_claw_x, preload);
  // 中心スタブ（本番同様: ホーン中心くぼみへ嵌合、床から horn_thick/2 突出）
  translate([0, 0, floor_z - 0.1])
    cylinder(d = horn_stub_d, h = horn_thick/2 + 0.1);
}

for (i = [0 : len(hs_preloads) - 1])
  translate([0, i * (hs_bw + 4), 0])
    snap_block(hs_preloads[i], i + 1);
