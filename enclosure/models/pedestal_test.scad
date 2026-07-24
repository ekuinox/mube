include <params.scad>
use <pedestal.scad>
// v3: サーボ天板がオフセット位置にあり、カラーが定義されること
assert(servo_ears_z - wall > ped_window_z1, "サーボ天板が窓より上");
// TASK-7: 梁の帯・壁アンカーが gear_dir_deg 側の筒壁一片だけに根付き、ノブ中央上空へ
//   材料を出さないこと。帯の始まりが筒内半径以上（原点側=ノブ包絡側へ材料を引き込まない）。
assert(ped_cyl_ri >= knob_env_r + 0.5, "梁の帯始点(筒内半径)がノブ包絡に食い込む");
// 壁アンカー円が筒環へ確実に食い込む（融合）: 中心半径 ped_cyl_ri+1、半径 ped_arm_w/2 の円が
//   筒外半径まで届く（径方向の食い込み >= 2mm を担保）
assert((ped_cyl_ri + 1 + ped_arm_w/2) >= ped_cyl_ro + 2, "壁アンカー円の筒壁への食い込みが不足(>=2mm)");
pedestal();
echo("pedestal_test ok");
