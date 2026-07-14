// ===== Smart lock enclosure parameters (mm) =====

// --- Print / fit ---
wall          = 2.4;
fit_clearance = 0.4;
$fn           = 64;
box_corner_r  = 3;      // outer shell corner fillet radius
lid_lip_h     = 4;      // lid inner-lip depth

// --- SG90 servo (datasheet nominal) ---
servo_body_l  = 22.8;
servo_body_w  = 12.2;
servo_body_h  = 22.5;
servo_tab_l   = 32.5;   // 耳の先端間の全長（実測）
servo_tab_h   = 2.7;    // 耳の厚み（実測）
servo_shaft_d = 4.8;    // output boss / horn clearance
servo_case_sub_h = 4;   // 耳の下面→ケースの軸側の面（実測）。耳よりケースが下に出っ張る分
servo_head_dome_h = 4;  // ケース面→ギアヘッドのドーム先端面（実測）
servo_head_h  = servo_case_sub_h + servo_head_dome_h;  // 耳の下面→ギアヘッド先端面 (8)。天板はこの部分を貫通穴で逃がす
servo_shaft_offset = 5.25; // 出力軸の本体中心からの偏り（実測: 耳先端→軸中心 11、耳全長 32.5 の中央 16.25 との差）。軸=原点なので本体は +X 側へこの分ずれる
servo_screw_span  = 28.5;  // 耳のネジ穴 中心間（実測から算出: 穴中心は先端から 3-2/2=2mm → 32.5-2*2。穴径2mm・データシート公称27.6。mount_coupon 実機で位置一致を確認済み 2026-07-03）
servo_screw_pilot = 2.2;   // M2 セルフタッピング下穴径。印刷補正込み: A1 mini(0.4ノズル/0.2mm層)は小径縦穴が約0.4細く出るため、pilot_gauge.scad の実測で 2.2 が適合（設計1.8 は M2 が入らなかった）
servo_plate_t     = 3.5;   // 耳ネジが効くペデスタル天板の厚み。下穴は貫通で M2 噛み合いは最大 3.5mm。天板下面とソケット上面のすき間 = horn_h - servo_plate_t。手持ち M2x5 だと効き 5-2.7=2.3mm（暫定）、M2x6 調達で 3.3mm となり目標 3mm を満たす

// --- SG90 ホーン (付属ホーン, 一文字バー実装, 実測反映済み) ---
horn_arm_l      = 16.65;    // 腕の長さ 中心→先端（実測: 横腕 全長 33.3mm の半分）
horn_arm_w_base = 6.8;      // 腕幅 中心側（最も広い, 実測4.8+2.0補正）
horn_arm_w_tip  = 3.4;      // 腕幅 先端側（最も狭い, 実測）
horn_hub_d      = 8.0;      // 中央ハブ外径（実測6.0+2.0補正）
horn_thick      = 1.7;      // ホーン厚 Z方向の押し出し深さ（実測）
horn_clearance  = 0.3;      // ホーンポケット専用クリアランス (fit_clearance とは独立)
horn_stub_d     = 4.6;      // 中心突起の径。ホーン socket 側の中心くぼみ(実測≈4.6mm)へ嵌合させ上下左右ズレを止める
// 抜け止めネジは不要（軸方向はドア↔サーボ間でソケットが挟持されるため）。回り止めは一文字バーポケットのキー嵌合＋中心突起で担う。

// --- Raspberry Pi Pico W ---
pico_l        = 51.0;
pico_w        = 21.0;
pico_h        = 1.0;
pico_hole_d   = 2.1;
pico_hole_dx  = 47.0;   // mounting hole spacing along length
pico_hole_dy  = 11.4;   // mounting hole spacing across width
// GPIO ヘッダは両長辺・両面にピンが出るため、縁は掴めない。ヘッダより内側にある
// 四隅の φ2.1 マウント穴で固定する。下側ピンが基板下面から pico_pin_drop 突き出すので、
// 四隅スタンドオフで基板を浮かせて床から逃がし、上から M2 セルフタップで留める。
pico_pin_drop = 6.0;    // 下側 GPIO ピンの基板下面からの突き出し（実測=6, 暫定）
pico_boss_d   = 5.0;    // 四隅スタンドオフ外径
pico_boss_h   = pico_pin_drop + 0.5;  // スタンドオフ高（下ピン先端が床上 0.5mm で浮く）= 6.5
pico_screw_pilot = 2.1; // M2 セルフタップ下穴径（tray と同仕様。A1 mini 補正込みの実績値）
pico_screw_grip  = 5;   // セルフタップ効き深さ（スタンドオフ上面から）

// --- USB micro-B connector (Pico W) ---
usb_w           = 12.0;  // 開口幅はケーブルプラグ基準。コネクタ幅9では実機でプラグが通らず拡大(2026-07-04)。クリアランス込み設計開口 12.8
usb_h           = 6.0;
usb_connector_h = 2.6;   // connector body height above PCB (measured)

// --- Indicators ---
led_hole_d    = 5.2;
button_hole_d = 6.2;
led_btn_spacing = 16;   // center-to-center distance between LED and button

// --- Door-fit clearances from the thumb-turn axis (origin = rosette center) ---
clear_left  = 50;   // -X to door edge/frame（実測: ~50 未満の上限。精密値は未確定）
clear_down  = 65;   // -Y to door handle（実測: ~65 未満の上限。精密値は未確定）
rosette_d   = 45;   // circular escutcheon diameter (registration only)（実測）

// --- Thumb-turn knob (measured; trapezoid) ---
knob_w_base = 27.8;  // width at the door (base, wider)（実測）
knob_w_top  = 25.6;  // width at the tip (narrower)（実測）
knob_t      = 3.1;   // thickness（実測）
knob_h      = 30;    // protrusion from the door（実測: 仮値 11 から大幅増→台座が背高に）
knob_engage = 10;    // socket engagement depth (< knob_h)（実測）
socket_wall = 2.0;

// --- Servo horn + pedestal ---
servo_horn_stack  = 12.1;   // 耳の下面→装着ホーンのバー下面（実測: ギアヘッド8 + ホーン込み4.1）
horn_seat_clear   = 0.3;    // ホーンバー下面とポケット底のすき間（バーはポケット深さ2.0のうち1.7嵌合）
// ソケット上面から耳の載る面までの高さ。バーがポケットに嵌合した状態で
// サーボの耳が来る位置を実測スタックから逆算する
horn_h            = servo_horn_stack + horn_seat_clear - (horn_thick + horn_clearance);  // 10.4
socket_oh         = knob_engage + socket_wall + 6;   // socket total height (18)
pedestal_top_z    = (knob_h - knob_engage) + socket_oh + horn_h;  // 48.4: servo tabs rest here
pedestal_wall_t   = 2.5;    // pedestal wall thickness
wire_clearance    = 4;      // space above servo for wiring

// --- Interior extents from the axis at origin (mm) ---
// -X/-Y はドアクリアランスの硬い制約で不変。BB を収めるため +X/+Y に拡大する。
// （後続の Pico 配置・BB・トレイ定数が参照するため、依存順でここに置く）
ext_left  = 27;    // -X toward frame; <= clear_left
ext_right = 86;    // +X; BB ポケット右(76.5) + 固定ポスト + トレイ床(+X端84.5)に 1.5mm 余裕
ext_down  = 26;    // -Y toward handle; <= clear_down
ext_up    = 120;   // +Y free; BB ポケット上端(118.25) + 壁マージンを収める

inner_l = ext_left + ext_right;          // 111
inner_w = ext_down + ext_up;             // 146
// inner_h: servo stack is the tallest — pedestal_top(48.4) + servo(22.5) + clearance(4) - floor wall
inner_h = pedestal_top_z + servo_body_h + wire_clearance - wall; // 72.5

body_l = inner_l + 2*wall;               // 115.8
body_w = inner_w + 2*wall;               // 150.8
body_h = inner_h + 2*wall;

// body center relative to the axis (axis sits low-left, body grows up-right)
center_x = (ext_right - ext_left) / 2;   // 28.5
center_y = (ext_up - ext_down) / 2;      // 47

// --- Pico placement in the +Y free space ---
// Pico は +Y 天井壁寄り（長軸 Y, USB は +Y 壁から）。USB プラグの届き量を master
// 同等（Pico の USB 端 → +Y 内壁 = pico_usb_gap）に保つよう pico_y を導出する。
// +Y 内壁の y は center_y + inner_w/2 = ext_up（恒等式）。
pico_usb_gap = 11;                            // Pico USB 端 → +Y 天井内壁（プラグ届き）
pico_x = 0;
pico_y = ext_up - pico_usb_gap - pico_l/2;    // 83.5
pedestal_outer = rosette_d/2 + pedestal_wall_t + fit_clearance;  // 25.4

// --- Breadboard (half-size, 実測 85.5 x 54.5mm) ---
// 浅い囲い壁ポケットへ落とし込む。厚み bb_t は形状に使わない（壁高で位置決め）。
bb_l = 85.5;              // long side (along Y)
bb_w = 54.5;              // short side (along X)
bb_t = 9.6;              // 実測厚（両面テープ込み）。押さえタブのフック高がこの値に依存
bb_clearance     = 0.5;   // BB 外形 → ポケット内壁のすき間
bb_pocket_wt     = 2.0;   // ポケット壁厚
bb_pocket_wall_h = 5.0;   // ポケット壁高（BB 下部を囲って位置決め）
// BB 押さえレール（上下短辺の囲い壁を BB 上面まで立て、内側へリップで浮き止め）
bb_rail_hook  = 1.5;      // リップの内側 overhang（BB 上端短辺へのかぶさり）
bb_rail_lip_h = 1.5;      // リップの縦厚（上面テーパーで傾け差し込みガイド）
pico_bb_gap      = 4;     // Pico 右端 → ポケット外壁左のすき間（ジャンパ差込）
bb_ped_gap       = 2.35;  // ポケット外壁下端 → ペデスタル外周のすき間

// BB 中心（ワールド座標）。ポケット外壁の左端が Pico 右端から pico_bb_gap、
// 下端がペデスタル外周から bb_ped_gap だけ離れるように置く。
bb_off_x = pico_x + pico_w/2 + pico_bb_gap + bb_pocket_wt + bb_clearance + bb_w/2;  // 44.25
bb_off_y = pedestal_outer + bb_ped_gap + bb_pocket_wt + bb_clearance + bb_l/2;      // 73

// BB ポケット内壁の端（BB 外形＋クリアランス）。Pico すき間を保つため -X（Pico 側）は
// 動かさず、反対の +X（ツメ2つの下辺）側だけ bb_ext_farx ぶん外へ広げる。
bb_ext_farx = 2.5;   // Pico と反対側(+X)へポケット内寸を拡張する量（Pico すき間 4mm を保つ）
pocket_inner_left   = bb_off_x - bb_w/2 - bb_clearance;                 // 16.5（元通り＝gap 保持）
pocket_inner_right  = bb_off_x + bb_w/2 + bb_clearance + bb_ext_farx;   // 74.5
pocket_inner_bottom = bb_off_y - bb_l/2 - bb_clearance;                 // 30.25
pocket_inner_top    = bb_off_y + bb_l/2 + bb_clearance;                 // 115.75
// ポケット外形の端（アサート・床範囲・固定ポスト配置の基準）
pocket_outer_left   = pocket_inner_left   - bb_pocket_wt;  // 14.5（元通り）
pocket_outer_right  = pocket_inner_right  + bb_pocket_wt;  // 76.5
pocket_outer_bottom = pocket_inner_bottom - bb_pocket_wt;  // 27.75
pocket_outer_top    = pocket_inner_top    + bb_pocket_wt;  // 118.25

// --- Electronics carrier tray ---
tray_t           = 2.4;    // tray floor thickness
tray_screw_pilot = 2.1;    // M2 self-tap 下穴（tray_pilot_gauge 実測の実績値）
tray_screw_grip  = 5;      // self-tap 効き深さ
tray_screw_clear = 2.4;    // M2 shank clearance（本体床の貫通）
tray_head_d      = 4.2;    // M2 pan-head counterbore 径（本体床裏）
tray_head_h      = 1.6;    // counterbore 深さ

// トレイ固定ポスト（専用。本体裏から M2 セルフタップで留める）。BB ポケットと
// Pico を避け、左ストリップ2本＋ポケット右2本に配置する。
tray_fix_d       = 6;      // 固定ポスト外径
tray_fix_h       = 6;      // 固定ポスト高（ネジ効き tray_screw_grip=5 + マージン）
tray_fix_gap     = 1;      // ポケット外壁 → 右ポストのすき間
tray_fix_x_left  = -20;    // 左ポスト列（Pico 左 -10.5 と壁 -27 の間）
tray_fix_x_right = pocket_outer_right + tray_fix_gap + tray_fix_d/2;  // 78
tray_fix_y_lo    = 40;
tray_fix_y_hi    = 100;
tray_fix_pts = [
  [tray_fix_x_left,  tray_fix_y_lo], [tray_fix_x_left,  tray_fix_y_hi],
  [tray_fix_x_right, tray_fix_y_lo], [tray_fix_x_right, tray_fix_y_hi],
];

// トレイ床矩形（Pico・ポケット・固定ポストを内包。1mm マージン）。
tray_x0 = tray_fix_x_left  - tray_fix_d/2 - 1;   // -24
tray_x1 = tray_fix_x_right + tray_fix_d/2 + 1;   // 82
tray_y0 = pocket_outer_bottom - 0.75;            // 27
tray_y1 = pocket_outer_top    + 0.25;            // 118.5


// --- Sanity / clearance checks ---
assert(wall > 0, "wall must be positive");
assert(fit_clearance >= 0, "fit_clearance must be >= 0");
assert(ext_left <= clear_left, "left extent exceeds door clearance");
assert(ext_down <= clear_down, "down extent exceeds handle clearance");
// Realized outer extents: body outer edge from origin = body_l/2 - center_x (-X) and body_w/2 - center_y (-Y)
assert(body_l/2 - center_x <= clear_left, "realized left extent exceeds door clearance");
assert(body_w/2 - center_y <= clear_down, "realized down extent exceeds handle clearance");
assert(knob_w_top <= knob_w_base, "knob tapers base->top");
assert(knob_engage < knob_h, "engagement shallower than protrusion");

// --- Servo mount checks ---
assert(servo_plate_t >= 3, "耳ネジの実効噛み合い（天板厚）>= 3mm");
assert(horn_h - servo_plate_t >= 0.5, "天板下面とソケット上面のクリアランス >= 0.5mm");
assert(servo_screw_pilot < servo_plate_t + 2, "下穴径が天板に対して常識的な範囲");
assert(horn_h - servo_head_h >= 0.3, "ギアヘッド先端が回転するソケット上面に触れない（すき間 >= 0.3mm）");
assert(servo_horn_stack - horn_h >= 1.0, "ホーンバーがソケット上面より下に >= 1mm 沈んで嵌合する");
assert(rosette_d/2 + pedestal_wall_t <= ext_left, "pedestal within interior (-X)");
assert(rosette_d/2 + pedestal_wall_t <= ext_down, "pedestal within interior (-Y)");

// --- ホーンパラメータ整合チェック ---
assert(horn_arm_w_base > horn_arm_w_tip, "ホーン腕幅: 中心側 > 先端側（テーパー方向）");
assert(horn_thick + horn_clearance <= horn_h, "ホーン厚+クリアランスが割当高さ以内");
assert(horn_hub_d >= horn_arm_w_base, "ハブ径 >= 腕幅中心側（中央ポケットはハブ circle が支配）");
assert(horn_stub_d < horn_hub_d, "中心突起径 < ハブ径（突起がハブくぼみに収まる）");
assert(horn_arm_l + horn_clearance + 0.4 <= (knob_w_base + knob_t)/2 + socket_wall, "ホーンバーがソケット外形内に収まる（先端壁 >= 0.4mm）");

// --- Electronics tray / breadboard layout checks ---
// Pico が +Y 天井壁寄りでペデスタルをクリア
assert(pico_y - pico_l/2 > pedestal_outer, "Pico -Y 端がペデスタルに干渉");
assert(pico_y + pico_l/2 <= ext_up, "Pico +Y 端が内寸を超える");
// USB プラグ届き量が正（Pico USB 端 → +Y 内壁 = pico_usb_gap）
assert(pico_usb_gap > 0 && ext_up - (pico_y + pico_l/2) >= pico_usb_gap - 0.01, "USB プラグ届き量が不足");
// Pico 四隅スタンドオフ: 下ピンを床から逃がし、下穴がスタンドオフ内に収まる
assert(pico_boss_h >= pico_pin_drop, "スタンドオフ高が下ピン突出を逃がせない");
assert(pico_screw_grip < pico_boss_h, "ネジ下穴 grip がスタンドオフ高を超える");
assert(pico_boss_d > pico_screw_pilot + 1.6, "スタンドオフ肉厚が下穴に対して薄すぎる");
// BB ポケットが内寸に収まる（+X/+Y 壁・ペデスタルをクリア）
assert(pocket_outer_right <= ext_right, "BB ポケット右端が +X 壁を超える");
assert(pocket_outer_top   <= ext_up,    "BB ポケット上端が +Y 壁を超える");
assert(pocket_outer_bottom >= pedestal_outer, "BB ポケット下端がペデスタルに干渉");
assert(bb_rail_hook > bb_clearance, "BB レールリップの overhang がクリアランス以下（掴めない）");
assert(pocket_outer_left  >= pico_x + pico_w/2 + pico_bb_gap - 0.001, "Pico↔BB ポケットのすき間不足");
// 固定ポストが BB・Pico・壁と干渉しない
assert(tray_fix_x_right - tray_fix_d/2 >= pocket_outer_right, "右固定ポストが BB ポケットに食い込む");
assert(tray_fix_x_right + tray_fix_d/2 <= ext_right, "右固定ポストが +X 壁を超える");
assert(tray_fix_x_left  + tray_fix_d/2 <= pico_x - pico_w/2, "左固定ポストが Pico に食い込む");
assert(tray_fix_x_left  - tray_fix_d/2 >= -ext_left, "左固定ポストが -X 壁を超える");
// トレイ床が内寸に収まる（ドロップイン可能）
assert(tray_x1 <= ext_right && tray_x0 >= -ext_left, "トレイ床 X が内寸を超える");
assert(tray_y1 <= ext_up && tray_y0 >= -ext_down, "トレイ床 Y が内寸を超える");
assert(tray_y0 >= pedestal_outer - 1, "トレイ床下端がペデスタルに寄りすぎ");
