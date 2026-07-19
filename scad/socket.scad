include <params.scad>

// Thumb-turn socket. Knob pocket on top (+Z) tapers from the tip (deep) to the
// base (opening); servo shaft bore on the bottom (-Z).
// v2: バー両脇のキャプチャ壁（z=-sock_wall_h..0）を追加。バーが数 mm 浮いても
// ポケットから外れないようにし、壁上端の 45° ファンネルで組み付けを誘導する。
// 印刷向きはノブ開口面（z=socket_oh 側）をベッドに（壁・スタブが上向きに立つ）。

// バー長手 x でのポケット半幅（バー部分のみ・クリアランス込み）
function sock_bar_hw(x) = horn_clearance +
  (horn_arm_w_tip + (horn_arm_w_base - horn_arm_w_tip) * (1 - abs(x)/horn_arm_l)) / 2;

// バーポケットの 2D 形状（テーパー一文字。ハブ円は含まない）
module horn_bar_2d() {
  polygon([
    [-horn_arm_l, -horn_arm_w_tip/2],
    [          0, -horn_arm_w_base/2],
    [ horn_arm_l, -horn_arm_w_tip/2],
    [ horn_arm_l,  horn_arm_w_tip/2],
    [          0,  horn_arm_w_base/2],
    [-horn_arm_l,  horn_arm_w_tip/2]
  ]);
}

// 押さえ爪の逃がし溝（4 箇所）。本体とキャプチャ壁の両方から引く
module sock_claw_slots() {
  for (sx = [-1, 1], sy = [0, 1])
    mirror([0, sy, 0])
      translate([sx * sock_claw_x - sock_claw_w/2 - sock_claw_side,
                 sock_bar_hw(sock_claw_x) - sock_claw_hk - 0.2,
                 -sock_wall_h - 0.1])
        cube([sock_claw_w + 2*sock_claw_side,
              sock_claw_hk + 0.2 + sock_claw_t + sock_claw_back,
              sock_wall_h + 0.1 + sock_claw_root]);
}

// +Y 側・中心 cx の押さえ爪。梁は Y 方向に撓み、返しのくさび下面がバーの
// サーボ側の面（ローカル z = horn_clearance）へ preload ぶん食い込む設計
module sock_claw(cx) {
  cy    = sock_bar_hw(cx);                      // 爪内面 = ポケット縁
  fz    = horn_clearance;                       // バーのサーボ側の面（ローカル z）
  press = fz + sock_claw_preload;               // くさびの爪面側（食い込み位置）
  tip   = fz - sock_claw_tipc;                  // くさび先端（面を僅かに越える）
  lead0 = tip - sock_claw_face - sock_claw_lead;
  // 梁（根元は本体スラブへ +1 食い込ませて融合）
  translate([cx - sock_claw_w/2, cy, lead0])
    cube([sock_claw_w, sock_claw_t, sock_claw_root + 1 - lead0]);
  // 返し（Y-Z 断面の多角形を X へ押し出し）
  translate([cx - sock_claw_w/2, cy, 0])
    rotate([90, 0, 90])
      linear_extrude(height = sock_claw_w)
        polygon([
          [            0, press],
          [-sock_claw_hk, tip],
          [-sock_claw_hk, tip - sock_claw_face],
          [            0, lead0],
        ]);
}

module thumbturn_socket() {
  c   = fit_clearance;
  hc  = horn_clearance;
  // outer footprint is knob-driven and capped so the R6-rounded body still clears the
  // pedestal bore (~rosette_d). The horn bar slot (33.3mm) just fits inside this.
  ow  = knob_w_base + knob_t + 2*socket_wall;
  difference() {
    // outer body: rounded square prism (R=6 for pedestal clearance)
    linear_extrude(height = socket_oh)
      offset(r = 6) offset(r = -6)
        square([ow, ow], center = true);
    // tapered knob pocket: base (knob_w_base) at the top opening, narrowing to
    // the tip (knob_w_top) at depth. Built tip-square at bottom, scaled up to base.
    translate([0, 0, socket_oh - knob_engage])
      linear_extrude(height = knob_engage + 0.1, scale = [knob_w_base/knob_w_top, 1])
        offset(r = c) square([knob_w_top, knob_t], center = true);
    // ホーンバーポケット: テーパー一文字バー＋ハブ円（底面＝シャフト側）
    translate([0, 0, -0.1]) {
      linear_extrude(height = horn_thick + hc + 0.1)
        offset(r = hc)
          union() {
            horn_bar_2d();
            circle(d = horn_hub_d);
          }
    }
    // 押さえ爪の逃がし溝: 内側は返しの通り道、背面は撓みしろまで。
    // ポケット縁と本体スラブを貫いて爪を切り離す
    if (socket_claws) sock_claw_slots();
  }
  // center registration stub: a nub protruding from the pocket floor (~half the horn
  // thickness) that nests into the horn's central recess (horn_stub_d, measured) to
  // stop the horn shifting up/down/left/right. No center retaining screw is used.
  translate([0, 0, (horn_thick + hc) - horn_thick/2])
    cylinder(d = horn_stub_d, h = horn_thick/2 + 0.1);
  // 押さえ爪（両先端付近の両脇・計 4 本、クーポン v4 準拠）。返しがバーの
  // サーボ側の面へ浅いくさびで被さり、梁のばね力を押さえ付けの面圧に変換する
  if (socket_claws)
    for (sx = [-1, 1], sy = [0, 1])
      mirror([0, sy, 0])
        sock_claw(sx * sock_claw_x);
  // キャプチャ壁: バー両脇の壁をサーボ側（-Z）へ sock_wall_h 延長する。
  // 中央はギアヘッドのドーム逃げで開け、バー先端方向（±X）は開放（薄壁スリバー回避。
  // バーは反対側の腕と対で嵌合するため X 方向へは抜けない）。
  difference() {
    translate([0, 0, -sock_wall_h])
      linear_extrude(height = sock_wall_h + 0.1)  // +0.1 本体へ食い込ませて融合
        intersection() {
          difference() {
            offset(r = hc + sock_wall_gap + sock_wall_t) horn_bar_2d();
            offset(r = hc + sock_wall_gap) horn_bar_2d();
          }
          for (s = [-1, 1])
            translate([s * (sock_wall_x0 + horn_arm_l + hc) / 2, 0])
              square([(horn_arm_l + hc) - sock_wall_x0, 40], center = true);
        }
    // 壁上端の 45° ファンネル（凸形状同士の hull で錐台を作って内面から引く）
    hull() {
      translate([0, 0, -sock_wall_h - 0.1])
        linear_extrude(height = 0.01)
          offset(r = hc + sock_wall_gap + sock_funnel) horn_bar_2d();
      translate([0, 0, -(sock_wall_h - sock_funnel)])
        linear_extrude(height = 0.01)
          offset(r = hc + sock_wall_gap) horn_bar_2d();
    }
    // 爪の逃がし溝（壁側にも通す。本体と別ソリッドのため両方から引く）
    if (socket_claws) sock_claw_slots();
  }
}
