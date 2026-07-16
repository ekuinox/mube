include <params.scad>
use <hardware.scad>
use <mount_plate.scad>

// Origin = thumb-turn / servo axis (center of the door rosette).
// オープンベースプレート構成: 外周壁・蓋・USB 開口は廃止（配線・USB は素通し）。
// 使用中の剛性は両面テープで貼るドアが担う。手持ち時の剛性リブは Task 4 で追加。
module body() {
  difference() {
    union() {
      // 床＋ペデスタル（Task 3 でボルトオン分離するまでは一体のまま）
      mount_plate();
      // トレイ固定ボス（天面 M2 留め）
      tray_mount_bosses();
    }
    // servo pocket at pedestal top; tabs rest on pedestal surface
    translate([0, 0, pedestal_top_z + servo_body_h/2])
      sg90_cutout();
  }
}
