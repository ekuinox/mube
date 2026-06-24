include <../scad/params.scad>
use <../scad/socket.scad>
// outer footprint must exceed the widest knob dimension with positive walls
assert(knob_w_base + 2*fit_clearance < knob_w_base + knob_t + 2*socket_wall, "pocket fits outer (Y)");
assert(knob_t + 2*fit_clearance < knob_w_base + knob_t + 2*socket_wall, "pocket fits outer (X)");
thumbturn_socket();
echo("socket_test ok");
