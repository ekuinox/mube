include <params.scad>

// Thumb-turn socket. Knob pocket on top (+Z) tapers from the tip (deep) to the
// base (opening); servo shaft bore on the bottom (-Z).
// v2: バー両脇のキャプチャ壁（z=-sock_wall_h..0）を追加。バーが数 mm 浮いても
// ポケットから外れないようにし、壁上端の 45° ファンネルで組み付けを誘導する。
// 印刷向きはノブ開口面（z=socket_oh 側）をベッドに（壁・スタブが上向きに立つ）。

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
  }
  // center registration stub: a nub protruding from the pocket floor (~half the horn
  // thickness) that nests into the horn's central recess (horn_stub_d, measured) to
  // stop the horn shifting up/down/left/right. No center retaining screw is used.
  translate([0, 0, (horn_thick + hc) - horn_thick/2])
    cylinder(d = horn_stub_d, h = horn_thick/2 + 0.1);
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
  }
}
