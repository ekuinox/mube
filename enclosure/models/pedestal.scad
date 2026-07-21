include <params.scad>
use <hardware.scad>

// ボルトオン・ペデスタル（ローカル座標: z=0 がフランジ底面。組立時はプレート床上面
// z=wall に載せる）。底フランジ（基礎円＋対角4ローブ）が受けカーブに落ちて軸センタリング、
// ローブがカーブ切り欠きと噛んでサーボ反力トルクの回り止め。固定はローブ上のスリーブ4個へ
// 天面から M2 セルフタップ（トレイと同構造・ファンネル穴）。クランプはネジ張力×フランジ底の
// プレート密着で効く。筒＋サーボ天板は旧 mount_plate と同形状で、天板上面はワールド
// pedestal_top_z(48.4) を維持する（ローカルでは pedestal_top_z - wall = 46）。
module pedestal() {
  c = fit_clearance;
  pr  = rosette_d/2 + pedestal_wall_t + c;   // 筒外半径 25.4（旧 mount_plate と同じ）
  top = pedestal_top_z - wall;               // 天板上面（ローカル 46）
  difference() {
    union() {
      // 底フランジ: 基礎円＋対角4ローブ（スリーブ受け兼回り止めタブ）。中央穴は difference 側
      linear_extrude(height = ped_flange_t)
        union() {
          circle(r = pr);
          for (p = ped_fix_pts)
            hull() {
              translate([p[0]/2, p[1]/2]) circle(d = ped_lobe_w);
              translate([p[0],   p[1]])   circle(d = ped_lobe_w);
            }
        }
      // 筒壁（フランジ内から天板まで。旧 mount_plate のリングと同径）
      linear_extrude(height = top)
        difference() {
          circle(r = pr);
          circle(r = pr - pedestal_wall_t);
        }
      // サーボ天板（旧 mount_plate と同一: 厚 servo_plate_t、シャフト穴＋耳ネジ下穴。
      // 下穴はサーボ本体中心（servo_shaft_offset ぶん偏心）基準の非対称配置）
      translate([0, 0, top - servo_plate_t])
        linear_extrude(height = servo_plate_t)
          difference() {
            circle(r = pr);
            circle(d = servo_shaft_d + 2*c);
            for (sx = [-1, 1])
              translate([servo_shaft_offset + sx * servo_screw_span/2, 0])
                circle(d = servo_screw_pilot);
          }
      // 固定スリーブ（トレイと同じ共有モジュール）
      for (p = ped_fix_pts)
        translate([p[0], p[1], 0]) m2_sleeve_solid();
    }
    // サーボポケット（天板にタブが載る。ローカル z 基準）
    translate([0, 0, top + servo_body_h/2])
      sg90_cutout();
    // 中央ロゼット通し（フランジを貫通）
    translate([0, 0, -0.1])
      cylinder(d = rosette_d + c, h = ped_flange_t + 0.2);
    // スリーブの内側カット（ボア/ファンネル/throat/頭ザグリ）
    for (p = ped_fix_pts)
      translate([p[0], p[1], 0]) m2_sleeve_cuts();
  }
}

// standalone render target (ignored by `use <pedestal.scad>`)
pedestal();
