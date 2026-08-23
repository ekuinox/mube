include <params.scad>
use <body.scad>
// カバー固定は 4 点
assert(len(cover_ear_pts) == 4, "カバー固定点は 4 点");
// プレート外形（素の角丸矩形）のドアクリアランス。-X/-Y 端を決めているのは矩形本体では
// なく「耳＋そのまわりの肉」なので、極値をここで組み立て直して見る（plate_x0 / plate_y0 を
// そのまま読むと、それを定義している min() と同じ式になって恒真化する）。
ear_x = max([for (p = cover_ear_pts) -p[0]]) + plate_ear_r;   // 38.0
ear_y = max([for (p = cover_ear_pts) -p[1]]) + plate_ear_r;   // 38.0
assert(ear_x <= clear_left, "耳まわりのプレートが -X のドアクリアランスを超える");
assert(ear_y <= clear_down, "耳まわりのプレートが -Y のドアクリアランスを超える");
// 外周リブの矩形はプレート外形の内側に収まること。リブはカバー裾の位置決めリップなので
// プレート外形とは独立に置いてあり、プレートより外へ出ると宙に浮いたリブになる。
assert(plate_rib_x0 >= plate_x0 && plate_rib_x1 <= plate_x1 &&
       plate_rib_y0 >= plate_y0 && plate_rib_y1 <= plate_y1,
       "外周リブの矩形がプレート外形からはみ出す");
// 耳のまわりのリブ逃げ（半径 (tray_sleeve_od+1)/2 = 4.4）が、その点でリブ帯を完全に
// 断ち切ること。断ち切れないとノズル幅未満の三日月壁が残る。リブ帯の外縁のうち耳から
// 最も遠いのは -Y 隅の角R の中心 (plate_rib_x0+cover_round_r, plate_rib_y0+cover_round_r)
// で、そこまでの距離が逃げ半径より小さければ角の四半円ごと消える。
rib_corner_far = norm([plate_rib_x0 + cover_round_r - (cover_x0 - cover_wall - cover_ear_off),
                       plate_rib_y0 + cover_round_r - (cover_y0 - cover_wall - cover_ear_off)]);
assert(rib_corner_far <= (tray_sleeve_od + 1)/2,
       "リブ逃げが小さく、-Y 隅にノズル幅未満の三日月リブが残る");
body();
echo("body_test ok");
