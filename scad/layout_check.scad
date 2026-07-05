// layout_check.scad — 寸法確認用レイアウト図（ワイヤーフレーム）
// 各パーツを 3D で実位置に配置し、projection() で投影後
// offset で輪郭線だけ抽出。重なったパーツも透けて見える。
//
// view: "side"  = Y-Z 横断面
// view: "front" = X-Y 正面図
// view: "both"  = 並べて表示
view = "both";

include <params.scad>

// ===== 派生値 =====
socket_z = knob_h - knob_engage;
socket_top_z = socket_z + socket_oh;
servo_z  = pedestal_top_z;
servo_top_z = servo_z + servo_body_h;
pico_floor_z = wall + tray_t;   // Pico はトレイ床(厚み tray_t)の上に載る
usb_z = pico_floor_z + pico_boss_h + pico_h + usb_connector_h/2;

uboard_z = pico_floor_z + pico_boss_h + pico_h + pin_header_h;

pedestal_r = rosette_d/2 + pedestal_wall_t + fit_clearance;
socket_ow = knob_w_base + knob_t + 2*socket_wall;

led_y = pico_y - led_btn_spacing/2;
btn_y = pico_y + led_btn_spacing/2;


// ===== 各パーツの 3D 形状（個別モジュール） =====
module part_rosette() {
  // ロゼット（ドア表面の化粧座、参考表示）
  translate([0, 0, 0.5])
    difference() {
      cylinder(d=rosette_d, h=1, center=true);
      cylinder(d=rosette_d - 3, h=2, center=true);
    }
}
module part_knob() {
  translate([0, 0, knob_h/2])
    cube([knob_w_base, knob_t, knob_h], center=true);
}
module part_socket() {
  translate([0, 0, socket_z + socket_oh/2])
    cube([socket_ow, socket_ow, socket_oh], center=true);
}
module part_horn() {
  translate([0, 0, socket_top_z + horn_h/2])
    cube([12, 12, horn_h], center=true);
}
module part_pedestal_walls() {
  // 円筒壁のみ（天面は別パーツ）
  translate([0, 0, pedestal_top_z/2])
    difference() {
      cylinder(r=pedestal_r, h=pedestal_top_z, center=true);
      cylinder(r=pedestal_r - pedestal_wall_t, h=pedestal_top_z+1, center=true);
    }
}
module part_pedestal_top() {
  // 天面（サーボ穴あり）
  translate([0, 0, pedestal_top_z - wall/2])
    difference() {
      cylinder(r=pedestal_r - pedestal_wall_t, h=wall, center=true);
      cylinder(d=servo_shaft_d + 2*fit_clearance, h=wall+1, center=true);
    }
}
module part_servo() {
  translate([0, 0, servo_z + servo_body_h/2])
    cube([servo_body_l, servo_body_w, servo_body_h], center=true);
}
module part_servo_tabs() {
  translate([0, 0, servo_z + servo_tab_h/2])
    cube([servo_tab_l, servo_body_w, servo_tab_h], center=true);
}
module part_pico() {
  // Pico 基板
  translate([pico_x, pico_y, pico_floor_z + pico_boss_h + pico_h/2])
    cube([pico_w, pico_l, pico_h], center=true);
  // マウントボス（床から立ち上がる台座）
  for (sx=[-1,1], sy=[-1,1])
    translate([pico_x + sx*pico_hole_dy/2, pico_y + sy*pico_hole_dx/2,
               pico_floor_z + pico_boss_h/2])
      cylinder(d=pico_boss_d, h=pico_boss_h, center=true);
}
module part_uboard() {
  translate([pico_x, pico_y, uboard_z + uboard_t/2])
    cube([uboard_w, uboard_l, uboard_t], center=true);
}
module part_led_btn() {
  translate([0, led_y, body_h]) cylinder(d=led_hole_d, h=wall, center=true);
  translate([0, btn_y, body_h]) cylinder(d=button_hole_d, h=wall, center=true);
}
module part_usb() {
  wall_y_top = center_y + inner_w/2;
  translate([pico_x, wall_y_top, usb_z])
    cube([usb_w, wall*2, usb_h], center=true);
}
// 外殻を壁・床・蓋に分離して、各投影で壁厚が見えるようにする
module part_body_walls() {
  // 4面の壁のみ（上下オープン）
  difference() {
    translate([center_x, center_y, body_h/2])
      cube([body_l, body_w, body_h], center=true);
    translate([center_x, center_y, body_h/2])
      cube([inner_l, inner_w, body_h + 1], center=true);
  }
}
module part_floor() {
  difference() {
    translate([center_x, center_y, wall/2])
      cube([inner_l, inner_w, wall], center=true);
    cylinder(d=rosette_d + fit_clearance, h=wall+1, center=true);
  }
}
module part_lid() {
  translate([center_x, center_y, body_h + wall/2]) {
    difference() {
      cube([body_l, body_w, wall], center=true);
      translate([0 - center_x, led_y - center_y, 0])
        cylinder(d=led_hole_d, h=wall+1, center=true);
      translate([0 - center_x, btn_y - center_y, 0])
        cylinder(d=button_hole_d, h=wall+1, center=true);
    }
  }
}


// ===== ワイヤーフレーム描画ヘルパー =====
lw = 0.4;
font = "Noto Sans CJK JP";
fs   = 4.0;
fs2  = 3.2;
fs3  = 2.6;

// 2D 輪郭線を抽出（塗りつぶしなし）
module wireframe() {
  difference() {
    children();
    offset(delta=-lw) children();
  }
}

// パーツを投影してワイヤーフレーム化（正面図用: Z方向投影）
module wf_front() { wireframe() projection(cut=false) children(); }

// パーツを投影してワイヤーフレーム化（横断面用: X方向投影→Y横軸, Z縦軸）
module wf_side() { wireframe() projection(cut=false) rotate([0, 0, -90]) rotate([0, -90, 0]) children(); }

// 直線
module hline(x1, x2, y) {
  translate([min(x1,x2), y - lw/2]) square([abs(x2-x1), lw]);
}
module vline(x, y1, y2) {
  translate([x - lw/2, min(y1,y2)]) square([lw, abs(y2-y1)]);
}

// 垂直寸法線
module vdim(y1, y2, x, label, right=true) {
  vline(x, y1, y2);
  hline(x-1.5, x+1.5, y1);
  hline(x-1.5, x+1.5, y2);
  tx = right ? x + 2 : x - 2;
  ha = right ? "left" : "right";
  translate([tx, (y1+y2)/2])
    text(label, size=fs3, font=font, halign=ha, valign="center");
}

// 水平寸法線
module hdim(x1, x2, y, label, above=true) {
  hline(x1, x2, y);
  vline(x1, y-1.5, y+1.5);
  vline(x2, y-1.5, y+1.5);
  ty = above ? y + 2 : y - 4;
  translate([(x1+x2)/2, ty])
    text(label, size=fs3, font=font, halign="center", valign="center");
}

// 引出線（点 → 折れ → ラベル）
// dir: 1=右向き(デフォルト), -1=左向き
module leader(px, py, lx, ly, label, dir=1) {
  translate([px, py]) circle(d=1.5);
  hline(px, lx, py);
  vline(lx, py, ly);
  bar_len = 25;
  if (dir > 0) {
    hline(lx, lx + bar_len, ly);
    translate([lx + 1, ly + 2])
      text(label, size=fs3, font=font);
  } else {
    hline(lx - bar_len, lx, ly);
    translate([lx - 1, ly + 2])
      text(label, size=fs3, font=font, halign="right");
  }
}


// ===== 正面図 =====
module front_view() {
  bx1 = center_x - body_l/2;
  bx2 = center_x + body_l/2;
  by1 = center_y - body_w/2;
  by2 = center_y + body_w/2;

  // 各パーツをワイヤーフレームで投影（外殻・蓋・床も 3D から）
  wf_front() part_body_walls();
  wf_front() part_floor();
  wf_front() part_lid();
  wf_front() part_rosette();
  wf_front() part_knob();
  wf_front() part_socket();
  wf_front() part_horn();
  wf_front() part_pedestal_walls();
  wf_front() part_pedestal_top();
  wf_front() part_servo();
  wf_front() part_servo_tabs();
  wf_front() part_pico();
  wf_front() part_uboard();
  wf_front() part_led_btn();
  wf_front() part_usb();

  // --- パーツ名ラベル（引出線、右に間隔6mmずつずらして重ならないように） ---
  lx1 = bx2 + 8;   // 第1列
  lx2 = bx2 + 18;  // 第2列
  // 下から順に Y を十分空けて配置
  leader(servo_body_l/2, 0, lx1, -15, "SG90 + 耳");
  leader(pedestal_r, 0, lx2, -8, "台座");
  leader(0, rosette_d/2, lx1, rosette_d/2 + 3, str("ロゼット Ø", rosette_d));
  leader(socket_ow/2, socket_ow/2, lx2, rosette_d/2 + 11, str("ソケット ", socket_ow, "x", socket_ow));

  leader(0, led_y, lx1, led_y, "LED");
  leader(0, btn_y, lx1, btn_y + 6, "BTN");
  leader(pico_w/2, pico_y, lx2, pico_y - 3, "Pico W");
  leader(uboard_w/2, pico_y + pico_l/4, lx2, pico_y + pico_l/4 + 8,
         str("基板 ", uboard_l, "x", uboard_w));

  // USB（上端）
  wall_y_top = center_y + inner_w/2;
  leader(usb_w/2, wall_y_top, lx1, wall_y_top - 3, "USB");

  // --- 寸法線 ---
  hdim(bx1, bx2, by2 + 14, str(body_l, " body_l"));
  vdim(by1, by2, lx2 + 40, str(body_w, " body_w"));
  hdim(bx1, 0, by1 - 12, str(body_l/2 - center_x, " 軸→左壁"), false);
  hdim(0, bx2, by1 - 20, str(body_l/2 + center_x, " 軸→右壁"), false);

  // --- タイトル・方向ラベル ---
  translate([center_x, by2 + 22])
    text("正面図（室内側から）", size=fs, font=font, halign="center");
  translate([center_x, by2 + 8])
    text("↑ ドア上方向", size=fs3, font=font, halign="center");
  translate([center_x, by1 - 8])
    text("↓ ドアノブ側", size=fs3, font=font, halign="center");
}


// ===== 横断面図 =====
// 投影後の座標: X = Y(3D), Y = Z(3D)
module side_view() {
  by1 = center_y - body_w/2;

  // 各パーツをワイヤーフレームで投影（外殻・蓋・床も 3D から）
  wf_side() part_body_walls();
  wf_side() part_floor();
  wf_side() part_lid();
  wf_side() part_rosette();
  wf_side() part_knob();
  wf_side() part_socket();
  wf_side() part_horn();
  wf_side() part_pedestal_walls();
  wf_side() part_pedestal_top();
  wf_side() part_servo();
  wf_side() part_servo_tabs();
  wf_side() part_pico();
  wf_side() part_uboard();
  wf_side() part_led_btn();
  wf_side() part_usb();

  // --- パーツ名ラベル（引出線、左に1列ずつずらして重ならない配置） ---
  lx1 = by1 - 12;   // 第1列（本体に近い）
  lx2 = by1 - 28;   // 第2列
  lx3 = by1 - 44;   // 第3列（最も遠い）
  // 各ラベルの Y 位置を 8mm 以上空ける
  leader(0, knob_h/2,                  lx1, 2,   "ノブ", -1);
  leader(0, socket_z + socket_oh/2,    lx2, 11,  "ソケット", -1);
  leader(0, socket_top_z + horn_h/2,   lx1, 20,  "ホーン", -1);
  leader(-pedestal_r, pedestal_top_z/2,lx3, 12,  "台座", -1);
  leader(0, servo_z + servo_body_h/2,  lx2, servo_z + servo_body_h/2, "SG90", -1);

  // Pico エリア（右側）
  lx_r = by1 + body_w + 12;
  leader(pico_y, pico_floor_z + pico_boss_h, lx_r, pico_floor_z + pico_boss_h, "Pico W");
  leader(pico_y, uboard_z + uboard_t, lx_r, uboard_z + uboard_t + 8,
         str("基板 ", uboard_l, "x", uboard_w));

  // --- 寸法線（左端、さらに外） ---
  dx1 = lx2 - 15;
  dx2 = dx1 - 14;
  vdim(0, knob_h, dx1, str(knob_h), false);
  vdim(socket_z, socket_top_z, dx2, str(socket_oh), false);
  vdim(socket_top_z, pedestal_top_z, dx1, str(horn_h), false);
  vdim(servo_z, servo_top_z, dx2, str(servo_body_h), false);
  vdim(servo_top_z, body_h - wall, dx1, str(wire_clearance), false);

  // 全高（右端遠く）
  vdim(0, body_h, lx_r + 35, str(body_h, " 全高"));

  // body_w（上部に水平寸法）
  hdim(by1, by1 + body_w, body_h + 22, str(body_w, " body_w"));

  // --- タイトル・方向ラベル ---
  translate([center_y, body_h + 30])
    text("横断面図（Y-Z 断面）", size=fs, font=font, halign="center");
  translate([center_y, body_h + 7])
    text("↑ 室内側", size=fs3, font=font, halign="center");
  translate([center_y, -8])
    text("↓ ドア面", size=fs3, font=font, halign="center");
  translate([by1 - 3, -8])
    text("← ドアノブ側", size=fs3, font=font, halign="right");
  translate([by1 + body_w + 3, -8])
    text("ドア上 →", size=fs3, font=font, halign="left");
}


// ===== メイン =====
draw_scale = 3;
if (view == "side") {
  scale([draw_scale, draw_scale]) side_view();
} else if (view == "front") {
  scale([draw_scale, draw_scale]) front_view();
} else {
  scale([draw_scale, draw_scale]) {
    side_view();
    translate([body_w + 40, 0]) front_view();
  }
}
