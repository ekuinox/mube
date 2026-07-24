// 部品間の体積干渉チェック用モデル。組立位置に置いた部品ペアの intersection を並べる。
// 干渉が無ければ全ペアが空になり、トップレベルは空（clash.ts が「empty」ログで PASS 判定）。
// 形状が出力された場合は干渉あり＝FAIL。
// 注意: 「空出力が正解」という逆セマンティクスなので render.sh / CI の汎用レンダリング
// ループでは回さないこと（空を FAIL 扱いされる）。判定は必ず clash.ts 経由で行う。
//
// 載せる側の部品は組立位置から clash_eps だけ +Z に浮かせる。意図的な面接触（トレイ床/
// フランジ底 vs プレート上面、ボス上面 vs ファンネル始端）は体積ゼロだが、intersection が
// 縮退シェルとして面を出してしまい偽陽性になるため。clash_eps 以下の浅い食い込みや
// 体積がほぼゼロの極薄スライバは検出できない代償があるが、実害レベルの食い込みは検出できる。
include <params.scad>
use <body.scad>
use <tray.scad>
use <pedestal.scad>
use <gears.scad>

clash_eps = 0.05;

// body × tray（トレイは組立位置 z=wall + 浮かせ）
intersection() {
  body();
  translate([0, 0, wall + clash_eps]) tray();
}

// body × pedestal（ペデスタルは組立位置 z=wall + 浮かせ）
intersection() {
  body();
  translate([0, 0, wall + clash_eps]) pedestal();
}

// tray × pedestal（どちらも組立位置。同一平面同士なので浮かせ不要＝相対位置は組立通り）
intersection() {
  translate([0, 0, wall]) tray();
  translate([0, 0, wall]) pedestal();
}

// ring_gear はワールド座標（z=wall 持ち上げ不要）。載せる側を clash_eps だけ +Z に浮かす。
// pedestal × ring_gear（受けカラー⇔スカートは径すき間で非接触のはず）
intersection() {
  translate([0, 0, wall]) pedestal();
  translate([0, 0, clash_eps]) ring_gear();
}
// pedestal × drive_gear（窓・梁と歯の接触検出。噛み合い位相で回した実姿勢）
intersection() {
  translate([0, 0, wall]) pedestal();
  translate([gear_axis_pos[0], gear_axis_pos[1], ring_z0 + clash_eps])
    rotate(gear_drive_phase) drive_gear();
}
// ring_gear × drive_gear（噛み合い部の食い込み検出。噛み合い位相合わせ）
intersection() {
  ring_gear();
  translate([gear_axis_pos[0], gear_axis_pos[1], ring_z0 + clash_eps])
    rotate(gear_drive_phase) drive_gear();
}
// tray × drive_gear（BB/トレイ側との干渉検出。噛み合い位相で回した実姿勢）
intersection() {
  translate([0, 0, wall]) tray();
  translate([gear_axis_pos[0], gear_axis_pos[1], ring_z0 + clash_eps])
    rotate(gear_drive_phase) drive_gear();
}

// ノブ包絡（TASK-7 回帰ガード）。サムターンノブは軸(原点)まわりに回転しながら
// プレート床上面(ワールド z≈0)からノブ先端(ワールド z = knob_h - mount_pad_t = 24)まで
// 突き出し、掴み代として露出し続けねばならない。回転包絡半径 knob_env_r に 0.5 の
// マージンを足した円柱を「ノブが占有し続ける空間」として定義し、これに触れる部品を検出する。
//   包絡下端は z=0.05（床上面のわずか上）から。上端は掴み代先端 z=24。
module knob_envelope() {
  translate([0, 0, 0.05]) cylinder(r = knob_env_r + 0.5, h = 24 - 0.05);
}
// knob_envelope × pedestal（梁・カラー等がノブ上空を横切らないこと）
intersection() {
  translate([0, 0, wall]) pedestal();
  knob_envelope();
}
// knob_envelope × drive_gear（駆動ギアはノブに一切触れてはならない）
intersection() {
  translate([gear_axis_pos[0], gear_axis_pos[1], ring_z0])
    rotate(gear_drive_phase) drive_gear();
  knob_envelope();
}
// 注記: ring_gear は意図的に除外する。リングギア下面のフォーク爪はノブ根元を押す
// 「押し子」であり、設計上ノブの回転路（包絡内）に入る。ここで対にすると必ず干渉検出
// されてしまうため、ノブに触れてはならない pedestal / drive_gear だけを対にする。
