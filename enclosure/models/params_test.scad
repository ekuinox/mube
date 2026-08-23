include <params.scad>
assert(body_l > 0 && body_w > 0, "positive plate dims");
assert(ext_left <= clear_left, "left extent within door clearance");
assert(ext_down <= clear_down, "down extent within handle clearance");
assert(knob_w_top <= knob_w_base, "knob tapers base->top");
assert(knob_engage < knob_h, "engagement shallower than protrusion");
// 基板レイアウト。中身のレイアウト検算は params.scad の assert 群が持っていて、
// このファイルは include するだけでそれを全部走らせる。ここには「params 側に
// 書くと定義式の書き写しになる」ものだけを置く（pcb_top_z の積み上げ確認は
// 定義そのものなので恒真、pcb 外形と受けカーブの関係は pcb_ped_gap >= 1 に縮退）。
assert(len(pcb_hole_pts) == 4 && pcb_l > pcb_w, "基板は横置き（長辺が X）で四隅穴");
echo("params_test ok");
sphere(0.01, $fn = 3);
