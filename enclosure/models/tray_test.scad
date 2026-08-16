include <params.scad>
use <tray.scad>
// 基板が支柱・床・固定スリーブのいずれとも整合すること（値は params の assert が担保）
assert(len(pcb_hole_pts) == 4, "基板の支柱は四隅 4 本");
assert(len(tray_fix_pts) == 4, "トレイ固定点は 4 点");
tray();
echo("tray_test ok");
