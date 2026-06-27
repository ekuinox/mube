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
pico_floor_z = wall;

pico_gap = max(6, rosette_d/2 - servo_body_w/2 + 2,
              rosette_d/2 + uboard_l/2 - pico_l/2 - servo_body_w/2 + 2);
pico_x = 0;
pico_y = servo_body_w/2 + pico_gap + pico_l/2;

pin_header_h = 8.5;
uboard_t = 1.6;
uboard_z = pico_floor_z + pico_boss_h + pico_h + pin_header_h;

pedestal_r = rosette_d/2 + pedestal_wall_t + fit_clearance;
socket_ow = knob_w_base + knob_t + 2*socket_wall;

led_y = pico_y - led_btn_spacing/2;
btn_y = pico_y + led_btn_spacing/2;


// ===== 各パーツの 3D 形状（個別モジュール） =====
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
module part_pedestal() {
  // 壁
  translate([0, 0, pedestal_top_z/2])
    difference() {
      cylinder(r=pedestal_r, h=pedestal_top_z, center=true);
      cylinder(r=pedestal_r - pedestal_wall_t, h=pedestal_top_z+1, center=true);
    }
  // 天面
  translate([0, 0, pedestal_top_z - wall/2])
    difference() {
      cylinder(r=pedestal_r, h=wall, center=true);
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
  translate([pico_x, pico_y, pico_floor_z + pico_boss_h + pico_h/2])
    cube([pico_w, pico_l, pico_h], center=true);
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
  translate([pico_x, wall_y_top, body_h*0.4])
    cube([usb_w, wall*2, usb_h], center=true);
}
module part_brace() {
  stub_len = clear_down - 4 - ext_down + 1;
  translate([0, -(ext_down) - stub_len/2 + 1, wall/2])
    cube([brace_stub_w, stub_len, wall], center=true);
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

// パーツを投影してワイヤーフレーム化（横断面用: X方向投影）
module wf_side() { wireframe() projection(cut=false) rotate([0, -90, 0]) children(); }

module outline_rect(x, y, w, h) {
  difference() {
    translate([x, y]) square([w, h]);
    translate([x+lw, y+lw]) square([w-2*lw, h-2*lw]);
  }
}


// ===== 正面図 =====
module front_view() {
  bx1 = center_x - body_l/2;
  by1 = center_y - body_w/2;

  // 各パーツをワイヤーフレームで投影
  wf_front() part_knob();
  wf_front() part_socket();
  wf_front() part_horn();
  wf_front() part_pedestal();
  wf_front() part_servo();
  wf_front() part_servo_tabs();
  wf_front() part_pico();
  wf_front() part_uboard();
  wf_front() part_led_btn();
  wf_front() part_usb();
  // part_brace は現在無効（両面テープ固定で十分の見込み）

  // 外殻枠線
  outline_rect(bx1, by1, body_l, body_w);

  // ラベル
  translate([center_x, by1 + body_w + 16])
    text("正面図（室内側から）", size=fs, font=font, halign="center");
  translate([center_x, by1 + body_w + 10])
    text(str(body_l, " x ", body_w, " mm"), size=fs2, font=font, halign="center");
  translate([center_x, by1 + body_w + 4])
    text("↑ ドア上方向", size=fs3, font=font, halign="center");
  translate([center_x, by1 - 6])
    text("↓ ドアノブ側", size=fs3, font=font, halign="center");
}


// ===== 横断面図 =====
module side_view() {
  by1 = center_y - body_w/2;

  // 各パーツをワイヤーフレームで投影
  wf_side() part_knob();
  wf_side() part_socket();
  wf_side() part_horn();
  wf_side() part_pedestal();
  wf_side() part_servo();
  wf_side() part_servo_tabs();
  wf_side() part_pico();
  wf_side() part_uboard();
  wf_side() part_led_btn();
  wf_side() part_usb();
  // part_brace は現在無効

  // 外殻枠線 (投影後: 横=Y, 縦=Z)
  outline_rect(by1, 0, body_w, body_h);

  // ラベル
  translate([center_y, body_h + 14])
    text("横断面図（Y-Z 断面）", size=fs, font=font, halign="center");
  translate([center_y, body_h + 8])
    text(str("body_h=", body_h, "  body_w=", body_w), size=fs2, font=font, halign="center");
  translate([center_y, body_h + 3])
    text("↑ 室内側", size=fs3, font=font, halign="center");
  translate([center_y, -6])
    text("↓ ドア面", size=fs3, font=font, halign="center");
  translate([by1 - 3, -6])
    text("← ドアノブ側", size=fs3, font=font, halign="right");
  translate([by1 + body_w + 3, -6])
    text("ドア上 →", size=fs3, font=font, halign="left");
}


// ===== メイン =====
draw_scale = 2;
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
