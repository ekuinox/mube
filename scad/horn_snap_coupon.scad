// ホーン抜け止めスナップ爪のクーポン（固定案 B）。
// 現行 socket のホーンバーポケット（テーパー一文字＋ハブ＋中心スタブ）を
// ミニブロック上面に複製し、バー両端に片持ちのスナップ爪を追加した試験片。
// 爪の返し量 2 種を 1 枚に並べ、実ホーンをパチンと嵌めて
// 「入れやすさ・保持力・外す時に爪が折れないか」を確かめる。
// 上面の溝線 1 本 = 予圧 0.15、2 本 = 予圧 0.30（左端寄り・幅 1.2 の彫り線）。
// 印刷向きは本番同等（ポケット面を上・爪は縦。爪の曲げは積層を剥がす向きに
// なるため、耐久はこのクーポンでの実測が正）。
// v2: v1（返し 0.5/0.8 のナイフエッジ三角）は返しの薄い部分がスライサーで
// 消えて印刷物に「ひさし」ができず、ホーンに噛まなかった。先端に垂直面
// hs_hook_face を持つ角張った断面へ変更し、返しも増量した。
// v3: v2 は噛むが上下にガタが残った。返し下面を水平から「内向きに下がる
// くさび」に変え、爪が閉じ切る前に下面がバー上面へ食い込んで予圧が掛かる
// ようにする（あそび 0 で押さえ込む）。予圧量 2 種を比較する。

include <params.scad>

hs_variants = [ [1.1, 0.15], [1.1, 0.30] ]; // [返し overhang, 予圧(バー上面への食い込み)]
hs_tip_clear = 0.05;    // 返し先端下面とバー上面のすき間（先端は必ずバーを越えられる）
hs_hook_face = 0.6;     // 返し先端の垂直面高さ。ナイフエッジ化による印刷消失を防ぐ
hs_claw_w = 6;    // 爪の幅
hs_claw_t = 1.2;  // 爪の梁厚。返し 1.1 のたわみでも曲げ歪み ~2.6% に収まる
hs_root_z = 1.0;  // 爪の根元高さ。ここから上が撓む（梁長 ~8.8mm）
hs_block_h = 10;  // ブロック高。ポケット床 = hs_block_h - (horn_thick + horn_clearance)
hs_bw     = 14;   // ブロック奥行き
hs_lead   = 1.4;  // 返しの上の 45° 差し込みガイド高
hs_relief = 1.3;  // 爪内側の逃がし幅（爪をブロック本体から切り離す。>= 返し量）
hs_side   = 0.8;  // 爪の左右の逃がし

pocket_d = horn_thick + horn_clearance;  // ポケット深さ 2.0
floor_z  = hs_block_h - pocket_d;        // ポケット床
bar_x    = horn_arm_l + horn_clearance;  // バー端 = 爪の内面
lx       = 2 * (bar_x + hs_claw_t);      // ブロック全長（爪の外面が端）

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

// +X 側の爪。梁＋返し。返し下面は「爪面側が低いくさび」:
// 爪面側の下端はバー上面より preload だけ低く、先端側は tip_clear だけ高い。
// 爪が内側へ戻る途中で下面がバー上面に楔当たりし、あそび 0 の予圧で押さえる
module claw(hk, preload) {
  hz_lo = floor_z + horn_thick - preload;  // 返し下面の爪面側（バー上面より低い）
  wedge = preload + hs_tip_clear;          // 下面の傾き量（先端はバー上面を越える）
  translate([bar_x, -hs_claw_w/2, hs_root_z])
    cube([hs_claw_t, hs_claw_w, hz_lo + wedge + hs_hook_face + hs_lead - hs_root_z]);
  translate([bar_x, hs_claw_w/2, 0])
    rotate([90, 0, 0])
      linear_extrude(height = hs_claw_w)
        polygon([
          [  0, hz_lo],
          [-hk, hz_lo + wedge],
          [-hk, hz_lo + wedge + hs_hook_face],
          [  0, hz_lo + wedge + hs_hook_face + hs_lead],
        ]);
}

module snap_block(hk, preload, notches) {
  difference() {
    translate([-lx/2, -hs_bw/2, 0])
      cube([lx, hs_bw, hs_block_h]);
    // ポケット（上面から掘る）
    translate([0, 0, floor_z])
      linear_extrude(height = pocket_d + 0.1)
        horn_pocket_2d();
    // 爪の切り離し: 根元から上を内側・左右に逃がし、外側は端面で開放
    for (m = [0, 1]) mirror([m, 0, 0])
      translate([bar_x - hs_relief, -(hs_claw_w + 2*hs_side)/2, hs_root_z])
        cube([hs_relief + hs_claw_t + 0.1, hs_claw_w + 2*hs_side, hs_block_h]);
    // 変種判別の溝線（上面左端寄り。1 本=予圧0.15 / 2 本=予圧0.30）
    for (t = [0 : notches - 1])
      translate([-lx/2 + 3 + t * 3, -hs_bw/2 - 0.1, hs_block_h - 0.8])
        cube([1.2, hs_bw + 0.2, 0.9]);
  }
  // 爪（両端）。根元 z=hs_root_z で本体の棚に着地して融合する
  for (m = [0, 1]) mirror([m, 0, 0])
    claw(hk, preload);
  // 中心スタブ（本番同様: ホーン中心くぼみへ嵌合、床から horn_thick/2 突出）
  translate([0, 0, floor_z - 0.1])
    cylinder(d = horn_stub_d, h = horn_thick/2 + 0.1);
}

for (i = [0 : len(hs_variants) - 1])
  translate([0, i * (hs_bw + 4), 0])
    snap_block(hs_variants[i][0], hs_variants[i][1], i + 1);
