include <params.scad>
use <body.scad>
use <lid.scad>
use <socket.scad>
use <tray.scad>

// Select with: openscad -D part="lid" ...
part = "assembly";
// exploded=0: assembled, exploded=1: exploded view
exploded = 1;

socket_z = knob_h - knob_engage;

exp = exploded ? 1 : 0;

if (part == "body") body();
else if (part == "lid") lid();
else if (part == "socket") thumbturn_socket();
else if (part == "tray") tray();
// トレイの +X/+Y 側の 1/4 象限を切り出したクーポン（ポスト高・ネジ効き・穴位置確認用）
else if (part == "tray_coupon")
  intersection() {
    tray();
    translate([0, 0, -1])
      cube([tray_fw/2 + 3, tray_fl/2 + 3, tray_post_h + tray_t + 3]);
  }
// ポケット周辺のみ切り出した薄型クーポン（ホーンフィット確認用）
else if (part == "socket_coupon")
  intersection() {
    thumbturn_socket();
    linear_extrude(height = horn_thick + horn_clearance + socket_wall + 0.5) // +0.5 = ポケット底面上のマージン
      square([200, 200], center = true);
  }
// ペデスタル天板のみ切り出した薄型クーポン（サーボ耳の位置・ネジ効き確認用）
else if (part == "mount_coupon")
  translate([0, 0, -(pedestal_top_z - servo_plate_t)]) // 天板下面をベッドに接地
    intersection() {
      body();
      translate([0, 0, pedestal_top_z - servo_plate_t])
        // 半径をペデスタル外周までに絞り、body の外壁を巻き込まない
        cylinder(r = rosette_d/2 + pedestal_wall_t + fit_clearance + 0.1,
                 h = servo_plate_t + 0.5); // +0.5 = 天板上面のマージン
    }
// 床フットプリントのみ切り出した薄型クーポン（ロゼット嵌合＋ドア左/下クリアランス確認用）。
// 床(wall)に加えて台座リングを 8mm 残し、ロゼットの出っ張りがボア(Ø45.8)へ逃げるかと
// +Y 壁の USB 開口（上端 z≈9.9）のプラグ通りも確認できるようにする
else if (part == "floor_coupon")
  intersection() {
    body();
    linear_extrude(height = wall + 8)
      square([300, 300], center = true);
  }
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
else if (part == "asm_tray")
  color("Plum")
    translate([pico_x, pico_y, wall + exp * 10]) tray();
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

  color("Plum")
    translate([pico_x, pico_y, wall + exp * 10]) tray();
}
