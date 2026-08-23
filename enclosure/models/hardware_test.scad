include <params.scad>
use <hardware.scad>
// Instantiate every module so undefined ones fail the compile.
difference() {
  cube([60, 40, 30], center = true);
  sg90_cutout();
}
pcb_standoff();
tray_mount_bosses();
ped_mount_bosses();
cover_mount_bosses();
m2_sleeve_solid();
difference() {
  cube([20, 20, 30], center = true);
  m2_sleeve_cuts();
}
echo("hardware_test ok");
