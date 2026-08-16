include <params.scad>
use <cover.scad>
// 屋根内面が中身の最高点を上回ること
assert(cover_inner_top >= servo_top_z + 1.5, "カバー天井がサーボに当たる");
assert(roof_in_z(pcb_off_y) >= pcb_top_z + pcb_stack_usb + 2, "屋根が Pico/USB に当たる");
// 「屋根が最高部品(pcb_stack_tall)に当たる」の assert は params.scad の
// pcb_tall_y_max > pcb_off_y - pcb_w/2 と代数的に同一（roof_in_z(pcb_off_y-pcb_w/2)
// >= pcb_top_z+pcb_stack_tall+2 を整理するとその式になる）なので重複させない。
assert(roof_in_z(pcb_off_y + pcb_w/2) >= pcb_top_z + pcb_stack_low, "屋根が基板 +Y 端に当たる");
// 屋根 × トレイ +Y 固定スリーブの干渉ガードは params.scad の Sanity セクションに移した
// （cover_tray_gap を参照。include されるどのモデルからでも常に効くほうが強いので、
// ここに重複させない。Ruling 10）。
// スイッチ（PS21B-1）が斜面に収まり本体が基板に当たらないこと
assert(cover_wall / cos(45) < sw_thread_l, "斜面の実効パネル厚がネジ部長さを超える");
assert(sw_panel_d > sw_thread_d, "取付穴がネジ部より小さい");
// 軸上の先端 sw_tip_z ではなく、φsw_body_d の掃引体の最下点（法線に垂直な
// (0,+1,-1)/√2 方向へ半径ぶんずれた点）が基板に当たるかを見る
assert(sw_tip_z - sw_body_d/2*cos(45) >= pcb_top_z + pcb_stack_pico,
       "スイッチ本体の掃引体が Pico に当たる");
assert(sw_pt[1] - sw_seat_d/2 >= cover_slope_y0, "スイッチ座面が勾配の始点をはみ出す");
assert(sw_pt[1] + sw_seat_d/2 <= cover_y1, "スイッチ座面が +Y 壁をはみ出す");
// LED 窓が基板の上にあること
assert(cover_led_pt[0] >= pcb_off_x - pcb_l/2 && cover_led_pt[0] <= pcb_off_x + pcb_l/2,
       "LED 窓が基板の X 範囲外");
assert(cover_led_pt[1] >= pcb_off_y - pcb_w/2 && cover_led_pt[1] <= pcb_off_y + pcb_w/2,
       "LED 窓が基板の Y 範囲外");
cover();
echo("cover_test ok");
