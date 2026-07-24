include <params.scad>
use <servo_tower.scad>
// サーボ塔: 天板上面（ローカル tower_top_local）がサーボ耳面 servo_ears_z と一致すること。
assert(tower_top_local == servo_ears_z - wall, "塔天板上面がサーボ耳面と不一致");
// サーボ天板下面がギア上を 19.5mm 以上でクリアすること（塔がギアに被らない下限）。
assert(tower_plate_bot_world >= 19.5, "サーボ天板下面がギア上を 19.5mm 以上でクリアしない");
// 固定ボス3点がいずれも駆動ギア掃引円（+1）の外側に立つこと。
for (p = tower_fix_pts)
  assert(sqrt(pow(p[0]-gear_axis_pos[0],2)+pow(p[1]-gear_axis_pos[1],2)) - tray_sleeve_od/2
           >= tower_gear_swept_r + 1 - 0.001,
         "塔スリーブが駆動ギア掃引円に食い込む");
servo_tower();
echo("servo_tower_test ok");
