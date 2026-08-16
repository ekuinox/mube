include <params.scad>
use <body.scad>
// カバー固定は 4 点。ラグはドアクリアランスの内側に収まる
assert(len(cover_ear_pts) == 4, "カバー固定点は 4 点");
lug_x = max([for (p = cover_ear_pts) -p[0]]) + plate_lug_d/2;
lug_y = max([for (p = cover_ear_pts) -p[1]]) + plate_lug_d/2;
assert(lug_x <= clear_left, "固定ラグが -X のドアクリアランスを超える");
assert(lug_y <= clear_down, "固定ラグが -Y のドアクリアランスを超える");
body();
echo("body_test ok");
