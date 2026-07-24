include <params.scad>
use <pedestal.scad>
// v4: 筒・噛み合い窓・持ち出し梁・サーボ天板は撤去済み。ペデスタルに残るのは受けカラー系のみ。
// 最上端（受けカラー上端 ped_collar_z1）がワールド 9.8 を超えないこと（サムターン周囲はオープン）。
assert(ped_collar_z1 <= servo_ears_z - wall + 0.001, "ペデスタル最上端が受けカラー上端を超える");
// ノブ包絡（r < knob_env_r）はペデスタルのどの要素にも侵されない（受けカラー内半径が包絡外）。
assert(ped_collar_ri > knob_env_r + 0.5, "受けカラー内面がノブ回転包絡に食い込む");
// 棚がフランジに直接根付く（棚下面 < フランジ厚）＝筒無しでも宙吊りにならない。
assert(ped_shelf_z0 < ped_flange_t, "内フランジ棚がフランジ実体に根付いていない");
pedestal();
echo("pedestal_test ok");
