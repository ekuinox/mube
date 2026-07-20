include <params.scad>
use <hardware.scad>
// Instantiate every module so undefined ones fail the compile.
difference() {
  cube([60, 40, 30], center = true);
  sg90_cutout();
}
pico_w_mounts();
tray_mount_bosses();
echo("hardware_test ok");
