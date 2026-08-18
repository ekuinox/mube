include <params.scad>
use <cover.scad>
// 屋根内面が中身の最高点を上回ること
assert(cover_inner_top >= servo_top_z + 1.5, "カバー天井がサーボに当たる");
// Pico は Y 方向に pico_w = 21 あるので、基板中心（pcb_off_y）ではなく Pico の +Y 端で
// 評価する。屋根は +Y ほど低いので、中心で見ると 10.5mm ぶん甘く出る。
assert(roof_in_z(pcb_off_y + pico_w/2) >= pcb_top_z + pcb_stack_usb + 2, "屋根が Pico/USB に当たる");
// 「屋根が最高部品(pcb_stack_tall)に当たる」の assert は params.scad の
// pcb_tall_y_max > pcb_off_y - pcb_w/2 と代数的に同一（roof_in_z(pcb_off_y-pcb_w/2)
// >= pcb_top_z+pcb_stack_tall+2 を整理するとその式になる）なので重複させない。
// 「屋根が基板 +Y 端の低背部品(pcb_stack_low)に当たる」の assert は、Ruling 12 で
// params.scad に入れた中背部品版（同じ評価点 pcb_off_y + pcb_w/2、pcb_stack_mid + 2）に
// 完全に包含される（3.0 < 12.0 + 2）ので置かない。
// 屋根 × トレイ +Y 固定スリーブの干渉ガードは params.scad の Sanity セクションに移した
// （cover_tray_gap を参照。include されるどのモデルからでも常に効くほうが強いので、
// ここに重複させない。Ruling 10）。
// スイッチ（PS21B-1）が平天面に収まり、本体がペデスタル／サーボに当たらないこと。
// 平天面の板厚は cover_wall ではなく cover_top_z - cover_inner_top = cover_wall*√2 = 2.83。
// 屋根を 45° の平面で切り落としているので、斜面で壁厚 2.0 を確保すると天面は √2 倍厚くなる。
// （斜面に付けていた頃は軸が法線方向で材料が斜めに切られず、厚みは cover_wall だった）
assert(cover_top_z - cover_inner_top < sw_thread_l, "平天面の板厚がネジ部長さを超える");
assert(sw_panel_d > sw_thread_d, "取付穴がネジ部より小さい");
// 本体は φsw_body_d の鉛直円柱を sw_depth 落とした柱。底面が水平なので下端はどこも
// sw_tip_z（軸上＝極値）。ペデスタル天板の上面をかわすこと。
assert(sw_tip_z >= pedestal_top_z, "スイッチ本体がペデスタル天板に当たる");
// 上の assert と対。柱の軸に最も近い点（中心距離 - 半径）がペデスタル筒の外半径より外に
// あること。現在値では上の z 側だけでも干渉は防げるが、sw_depth が伸びた途端に効く。
assert(norm(sw_pt) - sw_body_d/2 >= pedestal_outer, "スイッチ本体がペデスタル筒に当たる");
// サーボ（z 48.4〜70.9）は柱と z が重なるので、xy で離すしかない。サーボの +X 極値は
// 本体（servo_shaft_offset + servo_body_l/2 = 16.65）ではなく耳の先端なので耳で評価する。
assert(sw_pt[0] - sw_body_d/2 >= servo_shaft_offset + servo_tab_l/2,
       "スイッチ本体がサーボの耳に当たる");
// 座面 φsw_seat_d が平天面（y <= cover_slope_y0）に丸ごと収まり、内側でナットを締める
// 平面がカバー内腔の範囲にあること
assert(sw_pt[1] + sw_seat_d/2 <= cover_slope_y0, "スイッチ座面が斜面にかかる");
assert(sw_pt[1] - sw_seat_d/2 >= cover_y0, "スイッチ座面が -Y 壁をはみ出す");
assert(sw_pt[0] - sw_seat_d/2 >= cover_x0 && sw_pt[0] + sw_seat_d/2 <= cover_x1,
       "スイッチ座面が ±X 壁をはみ出す");
cover();
echo("cover_test ok");
