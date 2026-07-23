include <params.scad>
use <gears.scad>
// 半径の順序: 歯底 < ピッチ < 歯先
assert(gear_rr(gear_module, gear_z_ring) < gear_rp(gear_module, gear_z_ring), "rr < rp");
assert(gear_rp(gear_module, gear_z_ring) < gear_ra(gear_module, gear_z_ring), "rp < ra");
// リング歯底の内側にボア用のリムが残る
assert(gear_rr(gear_module, gear_z_ring) - ring_bore_d/2 >= 1.5, "ring rim >= 1.5");
// 噛み合い確認: 軸間距離に置いた 2 枚（位相合わせ済み）が重ならない
render() {
  difference() {
    intersection() {
      linear_extrude(height = 1) spur_gear_2d(gear_module, gear_z_ring);
      translate([gear_axis_dist, 0, 0])
        linear_extrude(height = 1)
          rotate(180/gear_z_drive)  // 駆動側を半歯ずらしてリングの歯と谷を合わせる
            spur_gear_2d(gear_module, gear_z_drive);
    }
  }
}
linear_extrude(height = 1) spur_gear_2d(gear_module, gear_z_ring);
echo("gears_test ok");
translate([0, -70, 0]) drive_gear();  // 駆動ギア（ホーン嵌合付き）
