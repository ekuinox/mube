include <params.scad>
use <body.scad>
use <pedestal.scad>
use <socket.scad>
use <tray.scad>
use <cover.scad>

// Select with: openscad -D part="body" ...
part = "assembly";
// exploded=0: assembled, exploded=1: exploded view
exploded = 1;

// ソケット下端の高さ（プレート座標）。ドア面はパッド厚ぶんプレートより下にある
socket_z = knob_h - knob_engage - mount_pad_t;

exp = exploded ? 1 : 0;

if (part == "body") body();
else if (part == "socket") thumbturn_socket();
else if (part == "tray") tray();
// カバーは天面をベッドに伏せて印刷する。組立向きから 180° 反転して天面を z=0 へ。
else if (part == "cover")
  translate([0, 0, cover_top_z]) rotate([180, 0, 0]) cover();
else if (part == "pedestal") pedestal();
// 本体ボス1本＋トレイスリーブ1個を並べた嵌合クーポン（横嵌め boss_fit・効き・クランプ確認用）。
// 右下の固定点を本物の body/tray からそのまま切り出す。両方とも床下面 z=0 がベッド接地。
else if (part == "tray_mount_coupon") {
  cx = tray_fix_x_right;
  cy = tray_fix_y_lo;
  hw = tray_sleeve_od/2 + 3;   // 切り出し半幅（隣のポケット縁/壁も少し含む）
  // 本体ボス側（床パッチ＋ボス1本）
  intersection() {
    body();
    translate([cx, cy, (wall + tray_boss_h + 2)/2 - 0.1])
      cube([2*hw, 2*hw, wall + tray_boss_h + 2], center = true);
  }
  // トレイスリーブ側（床パッチ＋スリーブ1個）。印刷用に +X へ退避。
  translate([2*hw + 8, 0, 0])
    intersection() {
      tray();
      translate([cx, cy, (tray_boss_h + tray_cap_t + 2)/2 - 0.1])
        cube([2*hw, 2*hw, tray_boss_h + tray_cap_t + 2], center = true);
    }
}
// ペデスタル固定の嵌合クーポン（フランジ⇔受けカーブの横嵌め pedestal_fit・ローブ⇔切り欠きの
// 噛み・M2 の効き・面一沈み確認用）。45° の固定点まわりを本物の body/pedestal から切り出す。
// 両方とも底面 z=0 がベッド接地。ペデスタル側は印刷用に +X へ退避。
else if (part == "ped_mount_coupon") {
  cp = ped_fix_pts[0];   // 45° の固定点 (≈21.2, 21.2)
  hw = 14;               // 切り出し半幅（カーブ切り欠き・ローブ・ボス・カーブ本体を含む）
  // プレート側（床パッチ＋ボス1本＋カーブの切り欠き部分）
  intersection() {
    body();
    translate([cp[0], cp[1], (wall + tray_boss_h + 2)/2 - 0.1])
      cube([2*hw, 2*hw, wall + tray_boss_h + 2], center = true);
  }
  // ペデスタル側（フランジローブ＋スリーブ1個＋筒壁の一部）
  translate([2*hw + 8, 0, 0])
    intersection() {
      pedestal();
      translate([cp[0], cp[1], (tray_boss_h + tray_cap_t + 2)/2 - 0.1])
        cube([2*hw, 2*hw, tray_boss_h + tray_cap_t + 2], center = true);
    }
}
// ポケット周辺のみ切り出した薄型クーポン（ホーンフィット＋キャプチャ壁確認用）
else if (part == "socket_coupon")
  intersection() {
    thumbturn_socket();
    translate([0, 0, -sock_wall_h - 0.5])
      linear_extrude(height = sock_wall_h + 0.5 + horn_thick + horn_clearance + socket_wall + 0.5)
        square([200, 200], center = true);
  }
// ペデスタル天板のみ切り出した薄型クーポン（サーボ耳の位置・ネジ効き確認用）
else if (part == "mount_coupon")
  translate([0, 0, -(pedestal_top_z - wall - servo_plate_t)]) // 天板下面をベッドに接地
    intersection() {
      pedestal();
      translate([0, 0, pedestal_top_z - wall - servo_plate_t])
        // 半径をペデスタル外周までに絞り、フランジ/スリーブを巻き込まない
        cylinder(r = rosette_d/2 + pedestal_wall_t + fit_clearance + 0.1,
                 h = servo_plate_t + 0.5);
    }
// 床フットプリントのみ切り出した薄型クーポン（ロゼット嵌合＋ドア左/下クリアランス確認用）。
// 台座は別部品化済みのため、ここに写るのは床＋受けカーブ(2.4mm)＋ボス根元まで。
// ロゼットの出っ張りが中央開口(Ø45.4)へ逃げるかを実ドアで当てて確認する。
else if (part == "floor_coupon")
  intersection() {
    body();
    linear_extrude(height = wall + 8)
      square([300, 300], center = true);
  }
// スイッチ（PS21B-1）取付部だけを切り出したクーポン（カバー全体を刷る前の座り確認用）。
// 本物の cover() から intersection で切り出すので、穴径 φsw_panel_d も平天面の板厚
// （cover_top_z - cover_inner_top = cover_wall*√2 = 2.83）も実物とそのまま同じ値になる。
// 印刷向きも本物と同じ「平天面をベッドに伏せる」（part="cover" と同じ反転を掛ける）ので、
// 穴は実物とまったく同じ条件で刷られる。
// 見るところ:
//  - φ12.0 の穴に φ11.5 のネジ部が入るか（印刷公差 0.5 で足りているか、渋いか、ガタか）
//  - 板厚 2.83 を挟んでもネジ部 8.3 の残り 5.47 でナットが十分に噛むか、締めたとき
//    フランジ φ18.7 が平天面へ隙間なく座るか（座面 φ19 の範囲が反りで浮いていないか）
else if (part == "sw_mount_coupon") {
  hw = sw_seat_d/2 + 4;        // 切り出し半幅（座面のまわりに 4mm の余白＝指で摘める幅）
  z0 = cover_inner_top - 1;    // 平天面のスラブを上下 1mm ずつ余して挟む
  z1 = cover_top_z + 1;
  // 切り出し箱が平天面の内側（±X 内壁 / -Y 内壁 / 勾配の始点）に収まること。はみ出すと
  // 壁や斜面を巻き込んで「板厚 2.83 の平板」でなくなり、実物と同じ条件の確認にならない。
  assert(sw_pt[0] - hw >= cover_x0 && sw_pt[0] + hw <= cover_x1 &&
         sw_pt[1] - hw >= cover_y0 && sw_pt[1] + hw <= cover_slope_y0,
         "スイッチクーポンの切り出し箱が平天面をはみ出す");
  translate([0, 0, cover_top_z]) rotate([180, 0, 0])
    intersection() {
      cover();
      translate([sw_pt[0], sw_pt[1], (z0 + z1)/2])
        cube([2*hw, 2*hw, z1 - z0], center = true);
    }
}
else if (part == "asm_body") color("SteelBlue") body();
else if (part == "asm_socket")
  color("SandyBrown")
    translate([0, 0, socket_z + socket_oh/2 - exp * 15])
      rotate([180, 0, 0])
        translate([0, 0, -socket_oh/2])
          thumbturn_socket();
else if (part == "asm_tray")
  color("Plum")
    translate([0, 0, wall + exp * 10]) tray();
else if (part == "asm_cover")
  color("LightSteelBlue") translate([0, 0, exp * 30]) cover();
else if (part == "asm_pedestal")
  color("Khaki")
    translate([0, 0, wall + exp * 8]) pedestal();
else {
  // full assembly
  color("SteelBlue") body();

  color("SandyBrown")
    translate([0, 0, socket_z + socket_oh/2 - exp * 15])
      rotate([180, 0, 0])
        translate([0, 0, -socket_oh/2])
          thumbturn_socket();

  color("Khaki")
    translate([0, 0, wall + exp * 8]) pedestal();

  color("Plum")
    translate([0, 0, wall + exp * 10]) tray();

  color("LightSteelBlue")
    translate([0, 0, exp * 30]) cover();
}
