include <../scad/params.scad>
use <../scad/hardware.scad>
// Instantiate every module so undefined ones fail the compile.
difference() {
  cube([60, 40, 30], center = true);
  sg90_cutout();
  usb_cutout();
  led_hole();
  button_hole();
  mosfet_space();
}
pico_w_mounts();
echo("hardware_test ok");
