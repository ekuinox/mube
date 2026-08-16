include <params.scad>
use <hardware.scad>

// 一体カバー（ワールド座標＝組立位置で構築。z = wall が裾の下端）。
// サーボ側が背高で、+Y へ 45° の単一勾配で降りる殻。印刷は天面をベッドに伏せる向きで、
// smartlock.scad の part="cover" がひっくり返す。屋根に水平な段を作らないのは、段が
// 第 1 層より下に宙で現れて垂れるため。
module cover() {
  difference() {
    union() {
      cover_shell();
      // 固定耳（裾の外へ張り出す。プレートのラグ上のボスに被さる）
      for (p = cover_ear_pts)
        translate([p[0], p[1], wall]) m2_sleeve_solid();
      cover_ear_webs();
    }
    for (p = cover_ear_pts)
      translate([p[0], p[1], wall]) m2_sleeve_cuts();
    cover_usb_cut();
    roof_normal_hole(cover_led_pt, cover_led_d);
    roof_normal_hole(sw_pt, sw_panel_d);
  }
}

// 固定耳と裾をつなぐウェブ。cover_ear_off は「耳の円が裾の角にちょうど接する」寸法だが、
// 裾の角は cover_round_r で丸めてあるので実際には 0.89mm 離れる。これが無いと耳は裾から
// 浮いた別部品になる（STL の連結成分が 5 個になる）。
// 橋は耳ごとに「最寄りの角の丸め円 ⇔ 耳の円」の凸包だけで架ける。裾の外形全体と凸包を
// 取ると、耳から遠い辺まで接線で結ばれて側壁の外にヒレが生える。
// z 帯はプレート外周リブの天面（wall + plate_rib_h）より上へ逃がす。リブは裾のすぐ外を
// 通り、リブ側の耳まわりの逃げ円（r 4.6）は裾の角（耳中心から 4.79）まで届かないので、
// リブと同じ高さでウェブを張るとカバーが座らなくなる。
module cover_ear_webs() {
  z0 = wall + plate_rib_h + fit_clearance;
  x0 = cover_x0 - cover_wall;   x1 = cover_x1 + cover_wall;
  y0 = cover_y0 - cover_wall;   y1 = cover_y1 + cover_wall;
  difference() {
    translate([0, 0, z0])
      linear_extrude(height = wall + tray_boss_h + tray_cap_t - z0)
        difference() {
          for (p = cover_ear_pts)
            hull() {
              // 耳に最も近い角の丸め円（＝角の実体そのもの）
              translate([p[0] < (x0 + x1)/2 ? x0 + cover_round_r : x1 - cover_round_r,
                         p[1] < (y0 + y1)/2 ? y0 + cover_round_r : y1 - cover_round_r])
                circle(r = cover_round_r);
              translate(p) circle(d = tray_sleeve_od);
            }
          cover_outline_2d(cover_wall);   // 内腔は塞がない
        }
    // 屋根面より上へはみ出させない（+Y 側は屋根がこの高さまで降りてくる）
    cover_roof_cut(cover_top_z);
  }
}

// 殻（外形 − 内腔）
module cover_shell() {
  difference() {
    cover_body(0,          cover_top_z,   wall);
    cover_body(cover_wall, cover_inner_top, wall - 1);
  }
}

// カバーのソリッド。inset だけ内側へ絞り、top_z の天面を 45° で切り落とす。
module cover_body(inset, top_z, z0) {
  difference() {
    translate([0, 0, z0])
      linear_extrude(height = top_z - z0)
        cover_outline_2d(inset);
    cover_roof_cut(top_z);
  }
}

// 角の丸め半径（cover_ear_webs が角の実体位置を出すのにも参照する）
cover_round_r = 2;

// 裾の外形 2D（inset で内腔用に絞る）
module cover_outline_2d(inset) {
  x0 = cover_x0 - cover_wall + inset;
  x1 = cover_x1 + cover_wall - inset;
  y0 = cover_y0 - cover_wall + inset;
  y1 = cover_y1 + cover_wall - inset;
  offset(r = cover_round_r) offset(r = -cover_round_r)
    translate([(x0 + x1)/2, (y0 + y1)/2])
      square([x1 - x0, y1 - y0], center = true);
}

// y + z >= cover_slope_y0 + top_z の半空間。45° の屋根勾配を作る。
// z >= 0 の厚いスラブを -45° 回して法線を (0,1,1)/√2 に向け、勾配の始点へ寄せる。
module cover_roof_cut(top_z) {
  translate([0, cover_slope_y0, top_z])
    rotate([-45, 0, 0])
      translate([-400, -400, 0]) cube([800, 800, 400]);
}

// 屋根の斜面に法線方向の素通し穴をあける。pt = [x, y]（ワールド）。
// rotate([-45,0,0]) はシリンダ軸 (0,0,1) を斜面の外向き法線 (0,√2/2,√2/2) に一致させる。
module roof_normal_hole(pt, d) {
  z = cover_top_z - (pt[1] - cover_slope_y0);
  translate([pt[0], pt[1], z])
    rotate([-45, 0, 0])
      translate([0, 0, -20])
        cylinder(d = d, h = 40, $fn = 48);
}

// USB 切欠き（+X 壁を厚み方向に貫く角穴）
module cover_usb_cut() {
  translate([cover_x1 + cover_wall/2, cover_usb_y, cover_usb_z])
    cube([cover_wall*3, cover_usb_w, cover_usb_h], center = true);
}

// standalone render target (ignored by `use <cover.scad>`)
cover();
