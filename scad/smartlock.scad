include <params.scad>
use <body.scad>
use <lid.scad>
use <socket.scad>

// Select with: openscad -D part="lid" ...
part = "assembly";

if (part == "body") body();
else if (part == "lid") lid();
else if (part == "socket") thumbturn_socket();
else {
  // assembly preview
  body();
  translate([0, 0, body_h + 2]) lid();
  translate([-inner_l/4, 0, body_h + 30]) thumbturn_socket();
}
