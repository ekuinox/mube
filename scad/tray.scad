include <params.scad>
use <hardware.scad>

// 電子部品トレイ（ワールド座標＝軸原点フレームで構築）。
// Pico を +Y 天井壁寄りに四隅スタンドオフで浮かせて載せ（両面ピンの下側を床から逃がす）、
// その右へブレッドボードを浅い囲い壁ポケットで落とし込む。四隅付近の固定スリーブが本体床の
// ボスに被さり、天面（内側）から M2 セルフタップでキャップ耳をボス上面へ締めて固定する。
// Pico は四隅穴へ上から M2 セルフタップで固定する。床は translate([0,0,wall]) で本体床上へ。
module tray() {
  difference() {
    union() {
      // 床プレート（Pico・ポケット・固定ポストを内包）
      translate([(tray_x0 + tray_x1)/2, (tray_y0 + tray_y1)/2, tray_t/2])
        cube([tray_x1 - tray_x0, tray_y1 - tray_y0, tray_t], center = true);

      // Pico 四隅スタンドオフ（長軸 Y ＝ 90 度回転）を Pico 中心へ
      translate([pico_x, pico_y, tray_t])
        rotate([0, 0, 90]) pico_w_mounts();

      // BB 囲い壁ポケット（Pico と反対の +X 側を bb_ext_farx 広げた非対称リング）。
      // 外形/内形の端をワールド座標の pocket_*_left/right/bottom/top から直に組む。
      translate([0, 0, tray_t])
        linear_extrude(height = bb_pocket_wall_h)
          difference() {
            translate([pocket_outer_left, pocket_outer_bottom])
              square([pocket_outer_right - pocket_outer_left,
                      pocket_outer_top - pocket_outer_bottom]);
            translate([pocket_inner_left, pocket_inner_bottom])
              square([pocket_inner_right - pocket_inner_left,
                      pocket_inner_top - pocket_inner_bottom]);
          }

      // BB 押さえレール（上下短辺のみ）。BB を傾けて短辺の下へ潜らせ、リップで浮き止め。
      // 両長辺はオープン（-X の Pico 側ジャンパが自由）。壁backingで丈夫＝しならず折れない。
      bb_rail(pocket_inner_top,    -1);   // +Y 短辺（内向き -Y）
      bb_rail(pocket_inner_bottom, +1);   // -Y 短辺（内向き +Y）

      // 固定スリーブ solid（内側は下の difference で彫る）。床下面 z=0 から立てるので床プレート
      // (0..tray_t) と重複するが union で合体するため問題ない（z=tray_t にするとスリーブが床面で
      // 分断される）。形状は hardware.scad の共有モジュール（トレイ/ペデスタル共用）。
      for (p = tray_fix_pts)
        translate([p[0], p[1], 0]) m2_sleeve_solid();
    }

    // 固定スリーブの内側カット（ボア/ファンネル/throat/頭ザグリ。hardware.scad の共有モジュール）
    for (p = tray_fix_pts)
      translate([p[0], p[1], 0]) m2_sleeve_cuts();

    // USB 向きマーカー（Pico の +Y 端側の床に凹み矢印）
    tray_usb_marker();
  }
}

// BB 押さえレール（短辺）。y_in = 短辺の内壁面 y、d = 内向き符号（+Y 短辺は -1、
// -Y 短辺は +1）。囲い壁を BB 上面(bb_t)まで立て、上端リップが内側へ bb_rail_hook
// だけ overhang して BB 上端の短辺を押さえる。リップ上面はテーパー（傾け差し込みガイド）。
// 壁で全長 backing されるので、しならず折れない。ポケット X 全幅にわたる。
module bb_rail(y_in, d) {
  x0 = pocket_outer_left;
  xw = pocket_outer_right - pocket_outer_left;
  // 壁を BB 上面まで（内壁面 y_in から外側 -d 方向へ bb_pocket_wt）
  wy0 = min(y_in, y_in - d*bb_pocket_wt);
  translate([x0, wy0, tray_t]) cube([xw, bb_pocket_wt, bb_t]);
  // リップ（下面=BB 上面、内側 d へ overhang、上へテーパー）
  hull() {
    ly0 = min(y_in + d*bb_rail_hook, y_in - d*bb_pocket_wt);
    translate([x0, ly0, tray_t + bb_t])
      cube([xw, bb_pocket_wt + bb_rail_hook, 0.4]);
    translate([x0, wy0, tray_t + bb_t + bb_rail_lip_h])
      cube([xw, bb_pocket_wt, 0.4]);
  }
}

// Pico の +Y（USB）端側を指す凹み矢印。USB 端はこちら＝本体 +Y 壁の開口に合わせる。
module tray_usb_marker() {
  depth = 0.6;
  translate([pico_x, pico_y + pico_l/2 - 6, tray_t - depth])
    linear_extrude(height = depth + 0.1)
      polygon(points = [[-2.5, 0], [2.5, 0], [0, 4.5]]);
}

// standalone render target (ignored by `use <tray.scad>`)
tray();
