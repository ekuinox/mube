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
      // 固定耳（裾の外へ張り出す。プレート上面のボスに被さる）
      for (p = cover_ear_pts)
        translate([p[0], p[1], wall]) m2_sleeve_solid();
      cover_ear_webs();
      cover_ear_gussets();
    }
    for (p = cover_ear_pts)
      translate([p[0], p[1], wall]) m2_sleeve_cuts();
    cover_ear_driver_bores();
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
      linear_extrude(height = cover_ear_top_z - z0)
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

// 固定耳のガセット（45°）。耳の天面（cover_ear_top_z）から裾の外面へ 45° で立ち上がる。
// 天面をベッドに伏せて刷るので、耳の天面はワールドで「上に何も無い」＝印刷では下向きの
// 水平面として、裾の外面から 6.7mm 片持ちで宙に現れる（ガセット無しの実測で 4 個 149mm²）。
// ガセットがあると耳は「先に刷られた裾の肉」から 45° で生えてくるので水平な張り出しが消え、
// ついでに耳の根元（φ7.8 の棒が厚さ 2.0 の壁から出ている所）が実際に太くなる。
// 形は「その高さでの裾外面の外側オフセット」で切った断面の積み重ね:
//   z = cover_ear_top_z + t の断面 = 耳のフットプリント ∩ offset(裾の外面, H - t)
// オフセットは凸な相手（直線壁 / 角の丸め円）に向かって単調に縮むので、どの層も 45° 以内で
// 内側へ寄る。t = H で断面が裾の肉そのものと一致して終わる＝ガセットの天は裾に載る。
//  - ±X 壁上の 2 点: 相手は直線の壁外面 → オフセットは平面なので 45° の斜め半空間で削ぐ。
//  - -Y の 2 隅:     相手は角の丸め円   → オフセットは同心円なので 45° のコーンで削ぐ。
//    こちらはウェブ（cover_ear_webs）も一緒に支える必要があるので、断面は耳の円ではなく
//    「角の丸め円 ⇔ 耳の円」の凸包（＝ウェブと同じフットプリント）を使う。
// z 帯はウェブの上端（cover_ear_top_z）から始まるのでウェブとは面で繋がるだけ。プレート側の
// 外周リブ（天面 wall + plate_rib_h = 6.4）とカバー固定ボス（天面 8.4）はどちらもこの帯より
// 下なので当たらない。
module cover_ear_gussets() {
  x0 = cover_x0 - cover_wall;   x1 = cover_x1 + cover_wall;
  y0 = cover_y0 - cover_wall;   y1 = cover_y1 + cover_wall;
  difference() {
    for (p = cover_ear_pts) {
      cx = p[0] < (x0 + x1)/2 ? x0 + cover_round_r : x1 - cover_round_r;
      cy = p[1] < (y0 + y1)/2 ? y0 + cover_round_r : y1 - cover_round_r;
      wx = p[0] < (x0 + x1)/2 ? x0 : x1;          // 相手になる壁の外面
      s  = p[0] < (x0 + x1)/2 ? 1 : -1;           // 壁から見た耳の向き（+X が 1）
      if ((p[0] < x0 + cover_round_r || p[0] > x1 - cover_round_r) &&
          (p[1] < y0 + cover_round_r || p[1] > y1 - cover_round_r))
        intersection() {
          translate([0, 0, cover_ear_top_z])
            linear_extrude(height = cover_gusset_h_corner)
              difference() {
                hull() {
                  translate([cx, cy]) circle(r = cover_round_r);
                  translate(p) circle(d = tray_sleeve_od);
                }
                cover_outline_2d(cover_wall);   // 内腔は塞がない
              }
          // 角の丸め円と同心のコーン。底面 r = 丸め半径 + H、天面 r = 丸め半径ちょうど
          // （＝角の実体そのもの）なので、天面が裾へそのまま載る。
          translate([cx, cy, cover_ear_top_z])
            cylinder(r1 = cover_round_r + cover_gusset_h_corner, r2 = cover_round_r,
                     h = cover_gusset_h_corner);
        }
      else
        intersection() {
          translate([0, 0, cover_ear_top_z])
            linear_extrude(height = cover_gusset_h_wall)
              difference() {
                translate(p) circle(d = tray_sleeve_od);
                cover_outline_2d(cover_wall);
              }
          // 壁の外面から H だけ外に出た所を起点に、+z へ 45° で壁側へ倒れる半空間。
          // rotate([0,45,0]) はローカル +x を (1,0,-1)/√2 に向けるので、ローカル x>=0 の
          // 立方体が「x - wx + H >= z - cover_ear_top_z」側（= 支えのある側）になる。
          translate([wx - s*cover_gusset_h_wall, p[1], cover_ear_top_z])
            rotate([0, s > 0 ? 45 : 135, 0])
              translate([0, -200, -200]) cube([400, 400, 400]);
        }
    }
    // 屋根面より上へはみ出させない（params.scad の「+Y の耳／ガセットが屋根を突き抜ける」
    // assert が守るので現在値では何も削らないが、保険として掛けておく）
    cover_roof_cut(cover_top_z);
  }
}

// ガセットを貫くドライバ穴。M2 は耳の天面から真下へ入るので、頭ザグリ（φtray_head_d）を
// ガセットの上まで真っ直ぐ延長して軸上を空けておく。径をザグリより広げると、その段差が
// 耳の天面に水平な張り出しとして戻ってくる（ガセットで消した分が復活する）ので同径に保つ。
// 穴は耳の中心から半径 tray_head_d/2 = 2.1 しかなく、裾の外面までは 2.8 あるので裾は削らない。
module cover_ear_driver_bores() {
  for (p = cover_ear_pts)
    translate([p[0], p[1], cover_ear_top_z - 0.1])
      cylinder(d = tray_head_d,
               h = max(cover_gusset_h_wall, cover_gusset_h_corner) + 0.2);
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
// 天面を伏せて刷ると print_z = (v - z_local)/√2 なので、上になるのはローカル +y（下り勾配）
// 側。したがって穴の天井は +y 側の平らな辺が掃く面で、これはローカル x と法線が張る平面
// ＝ ちょうど 45° のオーバーハングになる。面そのものが 45° なのでブリッジは発生せず、
// 各層のせり出しは層厚ぶんに留まる。
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
