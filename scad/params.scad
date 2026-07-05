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
pico_boss_d   = 4.5;
pico_boss_h   = 3.0;
// Pico is not screwed (a nut/head at the hole would hit the pin-header plastic).
// It rests on the bosses and is located by a pin entering each φ2.1 mounting hole;
// the soldered board (clamped to the posts) holds the Pico+board unit down.
pico_pin_d    = 1.9;    // locating pin dia (into the Pico φ2.1 hole)
pico_pin_h    = 2.0;    // pin height above the boss shoulder

// --- USB micro-B connector (Pico W) ---
usb_w           = 9.0;
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

// --- Universal board (stacked on Pico via pin headers) ---
uboard_l = 72;    // long side (along Pico pin direction = Y)
uboard_w = 47;    // short side (across Pico width = X)
uboard_t = 1.6;   // board thickness (P-03229 Cタイプ)

// Pico top face -> universal board underside gap (as-built). ヘッダ自由高さは
// 約 8mm だが、背高ポスト＋ネジで基板をここまで着座させる（ピンは約2mm深く挿さる）。
pin_header_h = 6;

// Universal board corner mounting holes (秋月 P-03229 datasheet).
uboard_mount_span_l = 66;   // corner-hole center pitch, long side (along Y)
uboard_mount_span_w = 41;   // corner-hole center pitch, short side (along X)
uboard_mount_d      = 3.2;  // corner hole dia (M2/M3 clearance)
// Measured board offset from the Pico center (USB-up top view: holes sit 1mm to
// the right and 1mm down from nominal). Applied to the posts and the body cuts.
uboard_mount_off_x  = 1;    // +X
uboard_mount_off_y  = -1;   // -Y

// --- Electronics carrier tray ---
tray_t            = 2.4;    // tray floor thickness
tray_post_d       = 6.0;    // universal-board support post outer dia
tray_post_h       = pico_boss_h + pico_h + pin_header_h;   // 10: post top = board underside
tray_fl           = uboard_mount_span_l + tray_post_d;     // 72: footprint along Y
tray_fw           = uboard_mount_span_w + tray_post_d;     // 47: footprint along X
tray_screw_clear  = 2.4;    // M2 shank clearance through the posts and body floor
// One M2 screw per corner clamps body + tray + board: it enters the body floor
// underside (head in a counterbore), passes up through the floor and the hollow
// support post, through the board's φ3.2 corner hole, and is capped by an M2 nut
// on top of the board (no plastic there). Needs ~M2x20 screws + 4 M2 nuts.
tray_head_d       = 4.2;    // M2 pan-head counterbore dia on the body floor underside
tray_head_h       = 1.6;    // counterbore depth

// --- Pico / tray placement in the +Y free space (single source; body/lid use these) ---
pedestal_outer = rosette_d/2 + pedestal_wall_t + fit_clearance;
pico_gap = max(6, pedestal_outer - servo_body_w/2 + 2,
              pedestal_outer + uboard_l/2 - pico_l/2 - servo_body_w/2 + 2);
pico_x = 0;
pico_y = servo_body_w/2 + pico_gap + pico_l/2;

// --- Interior extents from the axis at origin (mm) ---
ext_left  = 27;   // -X toward frame; must be <= clear_left (>= rosette_d/2)
ext_right = 27;   // +X; symmetric with ext_left
ext_down  = 26;   // -Y toward handle; must be <= clear_down (>= rosette_d/2 + pedestal)
ext_up    = 100;  // +Y free; houses Pico + universal board (72mm, clears pedestal)

inner_l = ext_left + ext_right;          // 54
inner_w = ext_down + ext_up;             // 126
// inner_h: servo stack is the tallest — pedestal_top(48.4) + servo(22.5) + clearance(4) - floor wall
inner_h = pedestal_top_z + servo_body_h + wire_clearance - wall; // 72.5

body_l = inner_l + 2*wall;
body_w = inner_w + 2*wall;
body_h = inner_h + 2*wall;

// body center relative to the axis (axis sits low-left, body grows up-right)
center_x = (ext_right - ext_left) / 2;   // 0
center_y = (ext_up - ext_down) / 2;      // 37

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

// --- Electronics tray checks ---
assert(tray_post_h > pico_boss_h + pico_h, "背高ポストは Pico 上面より高く基板を持ち上げる");
assert(uboard_mount_span_w/2 > pico_w/2, "uボード短辺マウント穴が Pico 幅の外");
assert(uboard_mount_span_l/2 > pico_l/2, "uボード長辺マウント穴が Pico 長さの外");
assert(uboard_mount_span_w <= uboard_w && uboard_mount_span_l <= uboard_l, "マウントピッチが基板外形内");
assert(tray_fw/2 <= inner_l/2, "トレイ footprint が内寸 X 内");
assert(pico_y + tray_fl/2 <= ext_up, "トレイ +Y 端が内寸を超える");
assert(pico_y - tray_fl/2 >= pedestal_outer, "トレイ -Y 端がペデスタルに干渉");
