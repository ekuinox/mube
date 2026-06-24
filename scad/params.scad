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

// --- Door-fit clearances from the thumb-turn axis (origin = rosette center) ---
clear_left  = 30;   // -X to door edge/frame
clear_down  = 40;   // -Y to door handle
rosette_d   = 46;   // circular escutcheon diameter (registration only)

// --- Thumb-turn knob (measured; trapezoid) ---
knob_w_base = 28;   // width at the door (base, wider)
knob_w_top  = 25;   // width at the tip (narrower)
knob_t      = 3;    // thickness
knob_h      = 11;   // protrusion from the door
knob_engage = 10;   // socket engagement depth (< knob_h)
socket_wall = 2.0;
knob_w      = knob_w_base;  // TEMP: removed in the socket task; keeps old socket.scad valid

// --- Interior extents from the axis at origin (mm) ---
ext_left  = 20;   // -X toward frame; must be <= clear_left
ext_right = 30;   // +X free
ext_down  = 14;   // -Y toward handle; must be <= clear_down
ext_up    = 64;   // +Y free; houses the Pico

inner_l = ext_left + ext_right;          // 50
inner_w = ext_down + ext_up;             // 78
inner_h = servo_body_h + pico_boss_h + 6;

body_l = inner_l + 2*wall;
body_w = inner_w + 2*wall;
body_h = inner_h + 2*wall;

// body center relative to the axis (axis sits low-left, body grows up-right)
center_x = (ext_right - ext_left) / 2;   // 5
center_y = (ext_up - ext_down) / 2;      // 25

// --- Sanity / clearance checks ---
assert(wall > 0, "wall must be positive");
assert(fit_clearance >= 0, "fit_clearance must be >= 0");
assert(ext_left <= clear_left, "left extent exceeds door clearance");
assert(ext_down <= clear_down, "down extent exceeds handle clearance");
assert(knob_w_top <= knob_w_base, "knob tapers base->top");
assert(knob_engage < knob_h, "engagement shallower than protrusion");
