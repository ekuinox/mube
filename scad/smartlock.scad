include <params.scad>
use <body.scad>
use <lid.scad>
use <socket.scad>

// Select with: openscad -D part="lid" ...
part = "assembly";
// exploded=0: assembled, exploded=1: exploded view
exploded = 1;

socket_oh = knob_engage + socket_wall + 6;
socket_z = knob_h - knob_engage;
horn_h = 4;

if (part == "body") body();
else if (part == "lid") lid();
else if (part == "socket") thumbturn_socket();
else {
  exp = exploded ? 1 : 0;

  // body at origin
  body();

  // lid (above body, small gap in exploded)
  translate([0, 0, body_h + exp * 5]) lid();

  // socket: flipped (knob pocket faces door = -Z), at axis
  // Z position: socket sits over the knob, shaft bore faces up toward servo
  translate([0, 0, socket_z + socket_oh/2 - exp * 15])
    rotate([180, 0, 0])
      translate([0, 0, -socket_oh/2])
        thumbturn_socket();
}
