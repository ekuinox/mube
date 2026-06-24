include <../scad/params.scad>
use <../scad/socket.scad>
// Pocket must not exceed socket outer size.
assert(knob_w + 2*fit_clearance < knob_w + knob_t + 2*socket_wall, "pocket fits within outer footprint (Y)");
assert(knob_t + 2*fit_clearance < knob_w + knob_t + 2*socket_wall, "pocket fits within outer footprint (X)");
thumbturn_socket();
echo("socket_test ok");
