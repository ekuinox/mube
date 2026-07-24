include <params.scad>
use <pedestal.scad>
// v3: サーボ天板がオフセット位置にあり、カラーが定義されること
assert(servo_ears_z - wall > ped_window_z1, "サーボ天板が窓より上");
pedestal();
echo("pedestal_test ok");
