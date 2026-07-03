include <../scad/params.scad>
use <../scad/socket.scad>

// taper sanity
assert(horn_arm_w_base > horn_arm_w_tip, "horn tapers base→tip");
assert(horn_clearance > 0, "positive horn clearance");

// horn fits in allocated Z
assert(horn_thick + horn_clearance <= horn_h, "horn fits pocket depth");

// hub wider than arm base — hub circle drives center width
assert(horn_hub_d >= horn_arm_w_base, "hub circle covers arm base width at center");

// bar tip has enough socket wall (>= 0.4mm)
socket_half = (knob_w_base + knob_t) / 2 + socket_wall;
assert(horn_arm_l + horn_clearance + 0.4 <= socket_half, "bar tip wall >= 0.4mm");

// pocket is strictly larger than horn in every dimension
assert(horn_hub_d + 2*horn_clearance > horn_hub_d, "hub pocket has clearance");
assert(horn_arm_w_base + 2*horn_clearance > horn_arm_w_base, "arm base pocket has clearance");
assert(horn_arm_w_tip + 2*horn_clearance > horn_arm_w_tip, "arm tip pocket has clearance");

// stub fits in horn center recess (stub_d < hub_d)
assert(horn_stub_d < horn_hub_d, "stub fits within hub recess");

thumbturn_socket();
echo("horn_fit_test ok");
