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
    cover_mesh_cut();
    flat_top_hole(sw_pt, sw_panel_d);
  }
}

// 角に置いた固定耳と裾をつなぐウェブ。cover_ear_off は「耳の円が裾の角にちょうど接する」
// 寸法だが、裾の角は cover_round_r で丸めてあるので実際には 0.89mm 離れる。これが無いと
// 耳は裾から浮いた別部品になる（STL の連結成分が 5 個になる）。
// 対象は「両軸とも角の丸め円より外」にある耳、すなわち -Y の 2 隅だけ。+Y の耳は ±X 壁の
// 直線部（y = tray_fix_y_hi）に置いてあり、そこには角丸めの引っ込みが無いので耳の円が裾外面へ
// 直接食い込む＝ウェブは要らない（params.scad の cover_ear_pts 参照）。
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
            if ((p[0] < x0 + cover_round_r || p[0] > x1 - cover_round_r) &&
                (p[1] < y0 + cover_round_r || p[1] > y1 - cover_round_r))
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

// 平天面に鉛直の素通し穴をあける。pt = [x, y]（ワールド）。パネル取付スイッチ用。
// 穴が斜面へかかると座面が折れ線をまたいでフランジが座らないので、穴の +Y 縁（直径ぶん）
// で判定する。座面 φsw_seat_d 側のより厳しい判定は cover_test.scad が持つ。
module flat_top_hole(pt, d) {
  assert(pt[1] + d/2 <= cover_slope_y0, "平天面の穴が勾配の始点を越えて斜面にかかる");
  translate([pt[0], pt[1], cover_top_z - 20])
    cylinder(d = d, h = 40, $fn = 48);
}

// 屋根の斜面に六角メッシュ（ハニカム）を開ける。LED の実装位置が未定なので、窓を一点に
// 決めずに斜面全体を透かして光をどこからでも逃がす。
// 穴の軸は鉛直ではなく斜面の法線: rotate([-45,0,0]) がシリンダ軸 (0,0,1) を外向き法線
// (0,√2/2,√2/2) に一致させ、同時に回転後のローカル xy が斜面そのものになる
// （ローカル x = ワールド x、ローカル y = 稜線からの「斜距離」で +Y へ下る向き。
//  ワールド y = cover_slope_y0 + v/√2 なので v = (ワールド y - cover_slope_y0)*√2）。
// 六角は $fn=6 の circle なので頂点が ±ローカル x、平らな辺が ±ローカル y に向く。
// 天面を伏せて刷るとローカル -y が上になるので、穴の天井は 45° の斜面上にある水平な辺
// ＝ 45° のオーバーハングになり、ブリッジは発生しない。
// 開ける範囲は稜線・+Y 内壁・±X 内壁から cover_mesh_margin を残した帯。+Y 側の基準を
// 外面（cover_y1 + cover_wall）ではなく内面（cover_y1）に取るのは、屋根が板として自立
// しているのがそこまでで、その先は +Y 壁の肉に載っているため。
module cover_mesh_cut() {
  p  = cover_mesh_af + cover_mesh_web;   // 六角中心の格子間隔（対辺の法線方向）
  rc = cover_mesh_af/sqrt(3);            // 外接円半径（circle(r) に渡す値）
  u0 = cover_x0 + cover_mesh_margin;   u1 = cover_x1 - cover_mesh_margin;
  v0 = cover_mesh_margin;
  v1 = (cover_y1 - cover_slope_y0)*sqrt(2) - cover_mesh_margin;
  uc = (u0 + u1)/2;   vc = (v0 + v1)/2;
  // 三角格子。列を p*√3/2 ごとに並べ、隣の列は p/2 ずらす。どの隣接方向でも中心間距離が
  // p になるので、平らな辺どうしの間に残る桟はどこも cover_mesh_web ちょうどになる。
  mmax = ceil((u1 - u0)/(p*sqrt(3))) + 1;
  nmax = ceil((v1 - v0)/(2*p)) + 2;
  // 六角の外接矩形（±rc × ±cover_mesh_af/2）が帯に収まるものだけ残す。半端に切られた
  // 六角は縁ぞいに極細のスライバを作るので、まるごと落とす方が安全。
  pts = [for (m = [-mmax : mmax], n = [-nmax : nmax])
           let (u = uc + m*p*sqrt(3)/2, v = vc + n*p + m*p/2)
           if (u - rc >= u0 && u + rc <= u1 &&
               v - cover_mesh_af/2 >= v0 && v + cover_mesh_af/2 <= v1)
             [u, v]];
  assert(len(pts) > 0, "ハニカムの穴が 1 個も置けない");
  translate([0, cover_slope_y0, cover_top_z])
    rotate([-45, 0, 0])
      linear_extrude(height = 20, center = true)
        for (q = pts) translate(q) circle(r = rc, $fn = 6);
}

// USB 切欠き（+X 壁を厚み方向に貫く角穴）
module cover_usb_cut() {
  translate([cover_x1 + cover_wall/2, cover_usb_y, cover_usb_z])
    cube([cover_wall*3, cover_usb_w, cover_usb_h], center = true);
}

// standalone render target (ignored by `use <cover.scad>`)
cover();
