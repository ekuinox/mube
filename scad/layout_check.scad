// layout_check.scad — 寸法確認用 2D 断面図
// nix develop -c bash -c 'openscad -o build/layout_check.svg scad/layout_check.scad && rsvg-convert -w 4800 -o build/layout_check.png build/layout_check.svg'
//
// view: "side"  = 横断面（ドア→室内の積み重なり）
// view: "front" = 正面図（本体を室内側から見た配置）
// view: "both"  = 並べて表示（デフォルト）
view = "both";

include <params.scad>

// ===== params.scad からの派生値 =====
// socket_oh, pedestal_top_z, horn_h, wire_clearance は params.scad で定義済み

socket_z = knob_h - knob_engage;                          // 1
socket_top_z = socket_z + socket_oh;                      // 19
servo_z  = pedestal_top_z;                                // 23
servo_top_z = servo_z + servo_body_h;                     // 45.5
pico_floor_z = wall;                                      // 2.4

// レイアウト図用の追加パラメータ（params 外）
uboard_t = 1.6;    // 基板厚み
pin_header_h = 8.5; // ピンヘッダ高さ
cap_h = 12;         // 最も背の高い部品（電解コン）

// 基板の Z 位置
uboard_z = pico_floor_z + pico_boss_h + pico_h + pin_header_h;

// ロゼットはみ出し量
rosette_overhang = rosette_d/2 - (body_l/2 - center_x);

// ===== 描画設定 =====
lw   = 0.5;
fs   = 4.0;    // タイトル
fs2  = 3.2;    // ラベル・寸法
fs3  = 2.6;    // 小注記
font = "Noto Sans CJK JP";

module hline(x1, x2, y, _lw=lw) {
  translate([min(x1,x2), y - _lw/2])
    square([abs(x2-x1), _lw]);
}
module vline(x, y1, y2, _lw=lw) {
  translate([x - _lw/2, min(y1,y2)])
    square([_lw, abs(y2-y1)]);
}

module vdim(y1, y2, x, label, right=true) {
  vline(x, y1, y2);
  hline(x-2, x+2, y1);
  hline(x-2, x+2, y2);
  tx = right ? x + 3 : x - 3;
  ha = right ? "left" : "right";
  translate([tx, (y1+y2)/2])
    text(label, size=fs2, font=font, halign=ha, valign="center");
}

module hdim(x1, x2, y, label, above=true) {
  hline(x1, x2, y);
  vline(x1, y-2, y+2);
  vline(x2, y-2, y+2);
  ty = above ? y + 3 : y - 5;
  translate([(x1+x2)/2, ty])
    text(label, size=fs2, font=font, halign="center", valign="center");
}

module part(x, y, w, h, label, _fs=0) {
  actual_fs = _fs > 0 ? _fs : fs2;
  translate([x, y]) {
    difference() {
      square([w, h]);
      translate([lw, lw]) square([w-2*lw, h-2*lw]);
    }
    translate([w/2, h/2])
      text(label, size=actual_fs, font=font, halign="center", valign="center");
  }
}


// ===== 横断面図（Y-Z 断面） =====
// 横軸 = Y（ドア上下方向）、縦軸 = Z（ドア面→室内）
module side_view() {
  // 本体の Y 範囲（実寸）
  by1 = -(ext_down + wall);   // 左端（ドアノブ側）
  by2 = ext_up + wall;        // 右端（ドア上方向）

  // Pico Y 位置（body.scad と同じ計算）
  pico_gap = max(6, rosette_d/2 - servo_body_w/2 + 2,
                rosette_d/2 + uboard_l/2 - pico_l/2 - servo_body_w/2 + 2);
  pico_cy = servo_body_w/2 + pico_gap + pico_l/2;

  // タイトル
  translate([(by1+by2)/2, body_h + 18])
    text("横断面図（Y-Z 断面）", size=fs, font=font, halign="center");
  translate([(by1+by2)/2, body_h + 12])
    text(str("body_h=", body_h, "  body_w=", body_w), size=fs2, font=font, halign="center");

  // ドア面（太帯）
  color([0.3, 0.3, 0.3]) {
    translate([by1 - 10, -4]) square([by2 - by1 + 20, 4]);
    translate([(by1+by2)/2, -8])
      text("↓ ドア面", size=fs2, font=font, halign="center", valign="center");
    translate([(by1+by2)/2, body_h + 4])
      text("↑ 室内側", size=fs3, font=font, halign="center", valign="center");
  }
  // ドア上下方向
  color([0.3, 0.3, 0.3]) {
    translate([by2 + 3, -8])
      text("ドア上 →", size=fs3, font=font, halign="left", valign="center");
    translate([by1 - 3, -8])
      text("← ドアノブ側", size=fs3, font=font, halign="right", valign="center");
  }

  // 本体外壁
  color([0, 0, 0]) {
    vline(by1, 0, body_h, 0.8);
    vline(by2, 0, body_h, 0.8);
    hline(by1, by2, body_h, 0.8);
    // 底面（中央に開口）
    hline(by1, -rosette_d/2 - 2, wall);
    hline(rosette_d/2 + 2, by2, wall);
  }

  // --- 軸まわり（Y=0 付近）--- 実寸で描画 ---

  // ノブ（Y-Z 断面でのサイズ = knob_t）
  color([0.7, 0.5, 0.3])
    part(-knob_t/2, 0, knob_t, knob_h, "ノブ");

  // ソケット（外寸 = knob_w_base + knob_t + 2*socket_wall）
  socket_ow = knob_w_base + knob_t + 2*socket_wall;
  color([0.3, 0.6, 0.8])
    part(-socket_ow/2, socket_z, socket_ow, socket_oh, "ソケット");

  // ホーン
  horn_w = 10;
  color([0.9, 0.9, 0.9])
    part(-horn_w/2, socket_top_z, horn_w, horn_h, "ホーン", fs3);

  // サーボ軸
  color([0.5, 0.5, 0.5])
    translate([-1.5, socket_top_z]) square([3, horn_h]);

  // 台座（ロゼット・ソケットを包み込む）
  pedestal_inner = rosette_d/2 + 2;
  pedestal_wall_t = 2.5;
  color([0.7, 0.6, 0.5]) {
    translate([-pedestal_inner - pedestal_wall_t, wall])
      square([pedestal_wall_t, pedestal_top_z - wall]);
    translate([pedestal_inner, wall])
      square([pedestal_wall_t, pedestal_top_z - wall]);
    translate([-pedestal_inner - pedestal_wall_t, pedestal_top_z - pedestal_wall_t])
      square([pedestal_inner - 4, pedestal_wall_t]);
    translate([4, pedestal_top_z - pedestal_wall_t])
      square([pedestal_inner - 4, pedestal_wall_t]);
    translate([-pedestal_inner - pedestal_wall_t - 3, (wall + pedestal_top_z)/2])
      text("台座", size=fs3, font=font, halign="right", valign="center");
  }

  // SG90（Y 方向の幅 = servo_body_w）
  color([0.4, 0.7, 0.4])
    part(-servo_body_w/2, servo_z, servo_body_w, servo_body_h, "SG90");

  // サーボ耳（Y 方向は本体と同じ幅）
  color([0.4, 0.7, 0.4])
    part(-servo_body_w/2, servo_z, servo_body_w, servo_tab_h, "耳", fs3);

  // --- Pico + 基板エリア（Y = pico_cy 付近）--- 実寸 ---

  // Pico（Y 方向 = pico_l = 51mm、90° 回転配置）
  color([0.8, 0.4, 0.4])
    part(pico_cy - pico_l/2, pico_floor_z + pico_boss_h,
         pico_l, pico_h, "Pico W");
  // ボス
  color([0.6, 0.6, 0.6]) {
    part(pico_cy - pico_l/2 + 2, pico_floor_z, 3, pico_boss_h, "");
    part(pico_cy + pico_l/2 - 5, pico_floor_z, 3, pico_boss_h, "");
  }
  // ピンヘッダ
  color([0.6, 0.6, 0.6]) {
    part(pico_cy - pico_l/2 + 2,
         pico_floor_z + pico_boss_h + pico_h, 2, pin_header_h, "");
    part(pico_cy + pico_l/2 - 4,
         pico_floor_z + pico_boss_h + pico_h, 2, pin_header_h, "");
  }
  // ユニバーサル基板（Y 方向 = uboard_l = 72mm）
  color([0.6, 0.3, 0.6])
    part(pico_cy - uboard_l/2, uboard_z,
         uboard_l, uboard_t, "基板 72×47");
  // C1（基板上の端）
  color([0.5, 0.5, 0.8])
    part(pico_cy + pico_l/2 + 2, uboard_z + uboard_t, 5, cap_h, "C1");

  // 底面床（Pico エリア）
  color([0, 0, 0])
    hline(rosette_d/2 + 2, by2, wall);

  // 開口ラベル
  translate([0, wall + 3])
    text("開口", size=fs3, font=font, halign="center", valign="center");

  // --- 寸法線 ---
  dim_y = body_h + 8;
  color([0.2, 0.2, 0.8]) {
    // 軸まわりの高さ寸法（左端に）
    vdim(0, knob_h, by1 - 8, str(knob_h, " ノブ"), false);
    vdim(socket_z, socket_top_z, by1 - 20, str(socket_oh, " ソケット"), false);
    vdim(socket_top_z, pedestal_top_z, by1 - 8, str(horn_h, " ホーン"), false);
    vdim(servo_z, servo_top_z, by1 - 32, str(servo_body_h, " SG90"), false);
  }

  // 全高（右端）
  color([0.8, 0.2, 0.2])
    vdim(0, body_h, by2 + 8, str(body_h, " 全高"));
}


// ===== 正面図 =====
module front_view() {
  // タイトル
  translate([center_x, body_w + 18])
    text("正面図（室内側から）", size=fs, font=font, halign="center");
  translate([center_x, body_w + 12])
    text(str(body_l, " x ", body_w, " mm"), size=fs2, font=font, halign="center");

  // 本体外枠
  bx1 = center_x - body_l/2;
  bx2 = center_x + body_l/2;
  by1 = center_y - body_w/2;
  by2 = center_y + body_w/2;

  color([0, 0, 0])
    part(bx1, by1, body_l, body_w, "");

  // ドア方向ラベル
  color([0.3, 0.3, 0.3]) {
    translate([center_x, by2 + 3])
      text("↑ ドア上方向", size=fs3, font=font, halign="center");
    translate([center_x, by1 - 6])
      text("↓ ドアノブ側", size=fs3, font=font, halign="center");
  }

  // ロゼット
  color([0.85, 0.85, 0.85])
    translate([0, 0]) difference() {
      circle(d=rosette_d);
      circle(d=rosette_d - 1.5);
    }

  // はみ出し部分を赤で強調 + 引出線
  if (rosette_overhang > 0) {
    ovh_x = -rosette_d/2;           // はみ出し先端
    ovh_y = 0;                      // 軸の高さ
    // 引出線の終点: 正面図の左下（寸法線より下）
    ldr_mid_x = ovh_x - 8;
    ldr_end_y = by1 - 32;
    color([1, 0, 0]) {
      // はみ出しマーク（先端に小さい丸）
      translate([ovh_x, ovh_y]) circle(d=2.5);
      // 引出線: マーク → 左に水平 → 下に垂直
      hline(ovh_x, ldr_mid_x, ovh_y, 0.6);
      vline(ldr_mid_x, ldr_end_y, ovh_y, 0.6);
      // 水平の引き出しバー
      hline(ldr_mid_x, ldr_mid_x + 40, ldr_end_y, 0.6);
      // テキスト（バーの上）
      translate([ldr_mid_x, ldr_end_y + 2])
        text(str("ロゼット(Ø", rosette_d, ")が左壁から ", rosette_overhang, "mm はみ出し"),
             size=fs3, font=font);
    }
  }

  // 軸マーク
  color([0.7, 0.5, 0.3]) {
    translate([0, 0]) circle(d=4);
    translate([3, -4])
      text("軸", size=fs3, font=font);
  }

  // SG90
  color([0.4, 0.7, 0.4]) {
    part(-servo_body_l/2, -servo_body_w/2,
         servo_body_l, servo_body_w, "SG90");
    // 耳
    part(-servo_tab_l/2, -servo_body_w/2,
         servo_tab_l, servo_body_w, "");
  }

  // Pico W + ユニバーサル基板
  pico_gap = max(6, rosette_d/2 - servo_body_w/2 + 2,
                rosette_d/2 + uboard_l/2 - pico_l/2 - servo_body_w/2 + 2);
  pico_cy = servo_body_w/2 + pico_gap + pico_l/2;

  // ユニバーサル基板（72×47mm、Pico に重ねて配置）
  // 長辺(72mm)を Y 方向、短辺(47mm)を X 方向
  // Pico 最終ピンが基板上端側に来るよう配置
  ub_cy = pico_cy;
  color([0.6, 0.3, 0.6, 0.3])
    part(-uboard_w/2, ub_cy - uboard_l/2,
         uboard_w, uboard_l, "");
  color([0.6, 0.3, 0.6])
    translate([-uboard_w/2 - 3, ub_cy])
      text("基板", size=fs3, font=font, halign="right", valign="center");
  color([0.6, 0.3, 0.6])
    translate([-uboard_w/2 - 3, ub_cy - 5])
      text("72×47", size=fs3, font=font, halign="right", valign="center");
  color([0.8, 0.4, 0.4])
    part(-pico_w/2, pico_cy - pico_l/2,
         pico_w, pico_l, "Pico W");

  // USB
  usb_y = center_y + inner_w/2;
  color([0.6, 0.6, 0.6])
    part(-usb_w/2, usb_y - 1.5, usb_w, 3, "USB");

  // LED + ボタン（Pico の真上、ピンヘッダ列の間に上下配置）
  led_y = pico_cy - led_btn_spacing/2;
  btn_y = pico_cy + led_btn_spacing/2;
  color([1, 0.8, 0])
    translate([0, led_y]) circle(d=led_hole_d);
  color([0.5, 0.5, 0.5])
    translate([0, btn_y]) circle(d=button_hole_d);
  translate([6, led_y])
    text("LED", size=fs3, font=font, valign="center");
  translate([6, btn_y])
    text("BTN", size=fs3, font=font, valign="center");

  // 寸法線（上）
  color([0.2, 0.2, 0.8])
    hdim(bx1, bx2, by2 + 8, str(body_l, " body_l"));

  // 寸法線（右）
  color([0.2, 0.2, 0.8])
    vdim(by1, by2, bx2 + 14, str(body_w, " body_w"));

  // 軸→壁（下に十分なスペースを取って配置）
  color([0.4, 0.4, 0.4]) {
    hdim(bx1, 0, by1 - 10,
         str(body_l/2 - center_x, " 軸→左壁"), false);
    hdim(0, bx2, by1 - 20,
         str(body_l/2 + center_x, " 軸→右壁"), false);
  }
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
    translate([160, 0]) front_view();
  }
}
