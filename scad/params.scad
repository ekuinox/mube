// ===== Smart lock enclosure parameters (mm) =====

// --- Print / fit ---
wall          = 2.4;
fit_clearance = 0.4;
$fn           = 64;
box_corner_r  = 3;      // outer shell corner fillet radius

// --- SG90 servo (datasheet nominal) ---
servo_body_l  = 22.8;
servo_body_w  = 12.2;
servo_body_h  = 22.5;
servo_tab_l   = 32.2;   // length across mounting tabs
servo_tab_h   = 2.5;
servo_shaft_d = 4.8;    // output boss / horn clearance
servo_screw_d = 2.0;

// --- Raspberry Pi Pico W ---
pico_l        = 51.0;
pico_w        = 21.0;
pico_h        = 1.0;
pico_hole_d   = 2.1;
pico_hole_dx  = 47.0;   // mounting hole spacing along length
pico_hole_dy  = 11.4;   // mounting hole spacing across width
pico_boss_d   = 4.5;
pico_boss_h   = 3.0;

// --- USB micro-B plug clearance (Pico W) ---
usb_w         = 9.0;
usb_h         = 6.0;

// --- Indicators ---
led_hole_d    = 5.2;
button_hole_d = 6.2;
led_btn_spacing = 16;   // center-to-center distance between LED and button

// --- MOSFET footprint (small module) ---
mosfet_w      = 12.0;
mosfet_l      = 16.0;

// --- Thumb-turn knob: PLACEHOLDER — measure real part, then set ---
knob_w        = 8.0;
knob_t        = 4.0;
knob_h        = 12.0;
socket_wall   = 2.0;

// --- Derived enclosure dimensions ---
inner_l = max(servo_tab_l, pico_l) + 6;
inner_w = servo_body_w + pico_w + 8;
inner_h = servo_body_h + pico_boss_h + 6;

body_l = inner_l + 2*wall;
body_w = inner_w + 2*wall;
body_h = inner_h + 2*wall;

// --- Sanity checks ---
assert(wall > 0, "wall must be positive");
assert(fit_clearance >= 0, "fit_clearance must be >= 0");
assert(inner_l >= pico_l, "body too short for Pico");
assert(inner_h >= servo_body_h, "body too short for servo");
