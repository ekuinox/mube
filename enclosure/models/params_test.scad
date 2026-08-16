include <params.scad>
assert(body_l > 0 && body_w > 0, "positive plate dims");
assert(ext_left <= clear_left, "left extent within door clearance");
assert(ext_down <= clear_down, "down extent within handle clearance");
assert(knob_w_top <= knob_w_base, "knob tapers base->top");
assert(knob_engage < knob_h, "engagement shallower than protrusion");
// 基板レイアウト
assert(pcb_off_y - pcb_w/2 >= ped_curb_ro + 1, "基板 -Y 端が受けカーブに近すぎる");
assert(abs(pcb_top_z - (wall + tray_t + pcb_standoff_h + pcb_t)) < 1e-6,
       "基板上面の Z が積み上げと一致");
echo("params_test ok");
sphere(0.01, $fn = 3);
