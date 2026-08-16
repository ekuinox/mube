include <params.scad>
use <hardware.scad>

// 電子部品トレイ（ワールド座標＝軸原点フレームで構築）。ユニバーサル基板 P-03229 を
// 四隅の支柱に載せ、四隅付近の固定スリーブが本体床のボスに被さって天面（内側）から
// M2 セルフタップで留まる。床の原点まわりはペデスタル受けカーブを丸く欠いてまたぐ。
module tray() {
  difference() {
    union() {
      // 床プレート（受けカーブの逃げ付き）
      linear_extrude(height = tray_t)
        difference() {
          translate([(tray_x0 + tray_x1)/2, (tray_y0 + tray_y1)/2])
            square([tray_x1 - tray_x0, tray_y1 - tray_y0], center = true);
          circle(r = tray_ped_notch_r);
        }

      // 基板支柱 4 本
      for (p = pcb_hole_pts)
        translate([p[0], p[1], tray_t]) pcb_standoff();

      // 固定スリーブ solid（内側は下の difference で彫る）。床下面 z=0 から立てる。
      for (p = tray_fix_pts)
        translate([p[0], p[1], 0]) m2_sleeve_solid();
    }

    // 固定スリーブの内側カット（ボア/ファンネル/throat/頭ザグリ）
    for (p = tray_fix_pts)
      translate([p[0], p[1], 0]) m2_sleeve_cuts();

    // USB 向きマーカー（基板の +X 端側の床に凹み矢印）
    tray_usb_marker();
  }
}

// Pico の USB が向く +X 側を指す凹み矢印。基板を載せる向きの目印。
module tray_usb_marker() {
  depth = 0.6;
  translate([pcb_off_x + pcb_l/2 - 6, pcb_off_y, tray_t - depth])
    rotate([0, 0, -90])
      linear_extrude(height = depth + 0.1)
        polygon(points = [[-2.5, 0], [2.5, 0], [0, 4.5]]);
}

// standalone render target (ignored by `use <tray.scad>`)
tray();
