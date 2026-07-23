include <params.scad>
use <hardware.scad>

// ===== インボリュート平歯車（標準・転位なし） =====
//
// 座標系: 歯 1 本の中心が +X 軸方向。
//
// インボリュート曲線の式（展開角 t は度）:
//   P(t) = rb * [ cos(t) + (πt/180)·sin(t),
//                 sin(t) - (πt/180)·cos(t) ]
//
// 歯厚の半角 (half):
//   ピッチ点での歯厚 = πm/2 [弧長] → 角度 = 90/z [deg]
//   involute 補正   = inv(pa) [rad→deg]
//   バックラッシュ  = (bl/2)/rp [rad→deg]
//
// ミラー側フランク: involute(t) の y を反転（x, -y）してから角度 +half 回転:
//   x' =  x·cos(half) + y·sin(half)
//   y' =  x·sin(half) - y·cos(half)

// ----- 基本寸法関数 -----

function gear_rp(m, z)     = m * z / 2;
function gear_rb(m, z, pa) = gear_rp(m, z) * cos(pa);
function gear_ra(m, z)     = gear_rp(m, z) + m;
function gear_rr(m, z)     = gear_rp(m, z) - 1.25 * m;

// ----- 内部ヘルパ -----

// inv(pa) をラジアンで返す
function _inv_rad(pa) = tan(pa) - pa * PI / 180;

// 展開角 t [deg] でのインボリュート点
function _inv_pt(rb, t) =
  let(tr = t * PI / 180)
  [rb * (cos(t) + tr * sin(t)),
   rb * (sin(t) - tr * cos(t))];

// 半径 r における展開角 [deg]（r < rb なら 0）
function _t_at(rb, r) = sqrt(max((r / rb) * (r / rb) - 1, 0)) * 180 / PI;

// 点 p を角度 a [deg] 回転（CCW）
function _rot(p, a) = [p[0]*cos(a) - p[1]*sin(a),
                       p[0]*sin(a) + p[1]*cos(a)];

// y を反転してから角度 a [deg] 回転（CCW）（ミラーフランク用）
function _rot_mir(p, a) = [ p[0]*cos(a) + p[1]*sin(a),
                             p[0]*sin(a) - p[1]*cos(a)];

// ----- 2D 歯車モジュール -----

module spur_gear_2d(m, z, pa = gear_pa, bl = gear_backlash) {
  rp = gear_rp(m, z);
  rb = gear_rb(m, z, pa);
  ra = gear_ra(m, z);
  rr = gear_rr(m, z);

  // フランクの開始半径（基礎円 > 歯底円のとき rb から、そうでなければ rr から）
  r0 = max(rr, rb);

  // 歯中心（+X）から片フランクまでの半角 [deg]
  half = 90 / z
       + _inv_rad(pa) * 180 / PI
       - (bl / 2) / rp * (180 / PI);

  n_pts = 16;  // フランク分割数（16 区間 / 17 点）

  // 右フランク点列（基礎円/歯底円 → 歯先）
  fl = [for (i = [0:n_pts])
    _inv_pt(rb, _t_at(rb, r0 + (ra - r0) * i / n_pts))];

  // 歯先端での位相角（フランク端点の極座標角）
  fl_tip_ang = atan2(fl[n_pts][1], fl[n_pts][0]);

  // 歯先円弧の角度範囲
  ang_r = fl_tip_ang - half;     // 右フランク端を -half 回転した角度
  ang_l = half - fl_tip_ang;     // 左フランク端（ミラー対称）

  n_tip = 6;  // 歯先弧の分割数

  union() {
    // 歯底円（全歯のベース）
    circle(r = rr, $fn = max(120, z * 4));

    // 各歯を回転配置
    for (k = [0:z - 1]) rotate(360 * k / z) {
      polygon(concat(
        // 根元閉じ点: polygon が歯底円内部で閉じるよう、
        // 歯底円上の中央付近の内点を加える（歯底 polygon と circle の重なりで実体化）
        [[rr * cos(0) * 0.5, 0]],

        // 右フランク（-half 方向に回転）
        [for (p = fl) _rot(p, -half)],

        // 歯先円弧（右フランク端 → 左フランク端）
        [for (i = [0:n_tip])
          [ra * cos(ang_r + (ang_l - ang_r) * i / n_tip),
           ra * sin(ang_r + (ang_l - ang_r) * i / n_tip)]],

        // 左フランク（+half 方向に回転、y を反転してミラー）
        [for (i = [n_pts:-1:0]) _rot_mir(fl[i], half)]
      ));
    }
  }
}

// 駆動ギア。サーボホーン（一文字バー）を上面ポケットへ嵌合し、押さえ爪でクリップする。
// ローカル座標: 盤下面 z=0、上面 z=gear_t。ホーンポケット開口は上面（+Z 側）。
//
// horn_pocket_* のローカル系: ポケット底 z=0、バー面が -Z 側。
// rotate([180,0,0]) + translate([0,0,gear_t]) でポケット底を gear_t 面に合わせ、
// バー面（-Z 方向）を gear_t より上（+Z 方向）に向ける。
//
// horn_pocket_cuts() に含まれる sock_claw_slots は爪よりも広い footprint を持ち、
// そのまま適用すると gear_t 上方の爪加算形状まで削り取ってしまう。
// そこで horn_pocket_cuts() の効果を z <= gear_t に限定（intersection で打ち切り）し、
// バー+ハブポケットは disk 内部（z=3..5 付近）に彫り込みつつ、
// gear_t 上方に立つ爪（sock_claw）は削り取られないようにする。
module drive_gear() {
  difference() {
    union() {
      linear_extrude(height = gear_t)
        spur_gear_2d(gear_module, gear_z_drive);
      // スタブ・爪の加算形状: 反転して上面へ。爪は gear_t より上に立つ。
      translate([0, 0, gear_t]) rotate([180, 0, 0]) horn_pocket_adds();
    }
    // ポケット彫り込み: z <= gear_t に限定して爪加算形状を削り取らないようにする。
    // （sock_claw_slots は爪と同 footprint のため、制限しないと爪ごと切除される）
    intersection() {
      translate([0, 0, gear_t]) rotate([180, 0, 0]) horn_pocket_cuts();
      translate([-200, -200, -200]) cube([400, 400, 200 + gear_t + 0.2]);
    }
  }
}
