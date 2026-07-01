include <params.scad>
use <body.scad>
use <lid.scad>
use <socket.scad>

// Select with: openscad -D part="lid" ...
part = "assembly";
// exploded=0: assembled, exploded=1: exploded view
exploded = 1;

socket_z = knob_h - knob_engage;
horn_h = 4;

exp = exploded ? 1 : 0;

if (part == "body") body();
else if (part == "lid") lid();
else if (part == "socket") thumbturn_socket();
else if (part == "asm_body") color("SteelBlue") body();
else if (part == "asm_lid")
  color("MediumSeaGreen")
    translate([0, 0, body_h + exp * 5]) lid();
else if (part == "asm_socket")
  color("SandyBrown")
    translate([0, 0, socket_z + socket_oh/2 - exp * 15])
      rotate([180, 0, 0])
        translate([0, 0, -socket_oh/2])
          thumbturn_socket();
else {
  // full assembly
  color("SteelBlue") body();

  color("MediumSeaGreen")
    translate([0, 0, body_h + exp * 5]) lid();

  color("SandyBrown")
    translate([0, 0, socket_z + socket_oh/2 - exp * 15])
      rotate([180, 0, 0])
        translate([0, 0, -socket_oh/2])
          thumbturn_socket();
}
