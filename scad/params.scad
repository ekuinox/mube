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
servo_tab_l   = 32.2;   // length across mounting tabs
servo_tab_h   = 2.5;
servo_shaft_d = 4.8;    // output boss / horn clearance
servo_screw_span  = 27.6;  // 耳のネジ穴 中心間（データシート公称・要実測補正）
servo_screw_pilot = 1.8;   // M2 セルフタッピング下穴径
servo_boss_d      = 4.5;   // 耳ボス外径（Pico ボスと同径。ポケット/タブ干渉を回避）
servo_boss_h      = 4.5;   // pedestal_top からの耳ボス高さ。実効ネジ噛み合いは sg90_cutout のタブスロット(Z≈22.6..25.9)がボス(Z≈23..27.5)を削るため上側 ~1.6mm のみ。M2 には浅く、ボス配置ごと要実測・要設計見直し

// --- SG90 cross horn (付属十字ホーン, 実測反映済み) ---
horn_arm_l      = 16.65;    // 腕の長さ 中心→先端（実測: 横腕 全長 33.3mm の半分）
horn_arm_w_base = 6.8;      // 腕幅 中心側（最も広い, 実測4.8+2.0補正）
horn_arm_w_tip  = 3.4;      // 腕幅 先端側（最も狭い, 実測）
horn_hub_d      = 8.0;      // 中央ハブ外径（実測6.0+2.0補正）
horn_thick      = 1.7;      // ホーン厚 Z方向の押し出し深さ（実測）
horn_clearance  = 0.3;      // ホーンポケット専用クリアランス (fit_clearance とは独立)
horn_stub_d     = 4.6;      // 中心突起の径。ホーン socket 側の中心くぼみ(実測≈4.6mm)へ嵌合させ上下左右ズレを止める
// 抜け止めネジは不要（軸方向はドア↔サーボ間でソケットが挟持されるため）。回り止めは十字ポケットのキー嵌合＋中心突起で担う。

// --- Raspberry Pi Pico W ---
pico_l        = 51.0;
pico_w        = 21.0;
pico_h        = 1.0;
pico_hole_d   = 2.1;
pico_hole_dx  = 47.0;   // mounting hole spacing along length
pico_hole_dy  = 11.4;   // mounting hole spacing across width
pico_boss_d   = 4.5;
pico_boss_h   = 3.0;

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
horn_h            = 4;      // horn thickness + clearance between socket top and servo tabs
socket_oh         = knob_engage + socket_wall + 6;   // socket total height (18)
pedestal_top_z    = (knob_h - knob_engage) + socket_oh + horn_h;  // 42: servo tabs rest here
pedestal_wall_t   = 2.5;    // pedestal wall thickness
wire_clearance    = 4;      // space above servo for wiring

// --- Universal board (stacked on Pico via pin headers) ---
uboard_l = 72;    // long side (along Pico pin direction = Y)
uboard_w = 47;    // short side (across Pico width = X)

// --- Interior extents from the axis at origin (mm) ---
ext_left  = 27;   // -X toward frame; must be <= clear_left (>= rosette_d/2)
ext_right = 27;   // +X; symmetric with ext_left
ext_down  = 26;   // -Y toward handle; must be <= clear_down (>= rosette_d/2 + pedestal)
ext_up    = 100;  // +Y free; houses Pico + universal board (72mm, clears pedestal)

inner_l = ext_left + ext_right;          // 54
inner_w = ext_down + ext_up;             // 126
// inner_h: servo stack is the tallest — pedestal_top(42) + servo(22.5) + clearance(4) - floor wall
inner_h = pedestal_top_z + servo_body_h + wire_clearance - wall; // 66.1

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
assert(servo_screw_pilot < servo_boss_d, "pilot hole smaller than boss");
assert(rosette_d/2 + pedestal_wall_t <= ext_left, "pedestal within interior (-X)");
assert(rosette_d/2 + pedestal_wall_t <= ext_down, "pedestal within interior (-Y)");

// Horn bar slot must fit inside the knob-driven socket footprint with >=0.4mm tip wall
assert(horn_arm_l + horn_clearance + 0.4 <= (knob_w_base + knob_t)/2 + socket_wall, "horn bar slot exceeds socket footprint (tip wall < 0.4mm)");
