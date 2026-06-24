include <../scad/params.scad>
use <../scad/socket.scad>
// Pocket must not exceed socket outer size.
assert(knob_w + 2*socket_wall <= knob_w + knob_t + 2*socket_wall, "socket sizing");
thumbturn_socket();
echo("socket_test ok");
