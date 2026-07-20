// ===== Smart lock enclosure parameters (mm) =====

// --- Print / fit ---
wall          = 2.4;
fit_clearance = 0.4;
$fn           = 64;

// --- SG90 servo (datasheet nominal) ---
servo_body_l  = 22.8;
servo_body_w  = 12.2;
servo_body_h  = 22.5;
servo_tab_l   = 32.5;   // 耳の先端間の全長（実測）
servo_tab_h   = 2.7;    // 耳の厚み（実測）
servo_shaft_d = 4.8;    // output boss / horn clearance
servo_case_sub_h = 4;   // 耳の下面→ケースの軸側の面（実測）。耳よりケースが下に出っ張る分
servo_head_dome_h = 4;  // ケース面→ギアヘッドのドーム先端面（実測）
servo_head_h  = servo_case_sub_h + servo_head_dome_h;  // 耳の下面→ギアヘッド先端面 (8)。天板はこの部分を貫通穴で逃がす
servo_shaft_offset = 5.25; // 出力軸の本体中心からの偏り（実測: 耳先端→軸中心 11、耳全長 32.5 の中央 16.25 との差）。軸=原点なので本体は +X 側へこの分ずれる
servo_screw_span  = 28.5;  // 耳のネジ穴 中心間（実測から算出: 穴中心は先端から 3-2/2=2mm → 32.5-2*2。穴径2mm・データシート公称27.6。mount_coupon 実機で位置一致を確認済み 2026-07-03）
servo_screw_pilot = 2.2;   // M2 セルフタッピング下穴径。印刷補正込み: A1 mini(0.4ノズル/0.2mm層)は小径縦穴が約0.4細く出るため、pilot_gauge.scad の実測で 2.2 が適合（設計1.8 は M2 が入らなかった）
servo_plate_t     = 3.5;   // 耳ネジが効くペデスタル天板の厚み。下穴は貫通で M2 噛み合いは最大 3.5mm。天板下面とソケット上面のすき間 = horn_h - servo_plate_t。手持ち M2x5 だと効き 5-2.7=2.3mm（暫定）、M2x6 調達で 3.3mm となり目標 3mm を満たす

// --- SG90 ホーン (付属ホーン, 一文字バー実装, 実測反映済み) ---
horn_arm_l      = 16.65;    // 腕の長さ 中心→先端（実測: 横腕 全長 33.3mm の半分）
horn_arm_w_base = 6.8;      // 腕幅 中心側（最も広い, 実測4.8+2.0補正）
horn_arm_w_tip  = 3.4;      // 腕幅 先端側（最も狭い, 実測）
horn_hub_d      = 8.0;      // 中央ハブ外径（実測6.0+2.0補正）
horn_thick      = 1.7;      // ホーン厚 Z方向の押し出し深さ（実測）
horn_clearance  = 0.3;      // ホーンポケット専用クリアランス (fit_clearance とは独立)
horn_stub_d     = 4.6;      // 中心突起の径。ホーン socket 側の中心くぼみ(実測≈4.6mm)へ嵌合させ上下左右ズレを止める
// 抜け止めネジは不要（軸方向はドア↔サーボ間でソケットが挟持されるため）。回り止めは一文字バーポケットのキー嵌合＋中心突起で担う。

// --- Raspberry Pi Pico W ---
pico_l        = 51.0;
pico_w        = 21.0;
pico_h        = 1.0;
pico_hole_d   = 2.1;
pico_hole_dx  = 47.0;   // mounting hole spacing along length
pico_hole_dy  = 11.4;   // mounting hole spacing across width
// GPIO ヘッダは両長辺・両面にピンが出るため、縁は掴めない。ヘッダより内側にある
// 四隅の φ2.1 マウント穴で固定する。下側ピンが基板下面から pico_pin_drop 突き出すので、
// 四隅スタンドオフで基板を浮かせて床から逃がし、上から M2 セルフタップで留める。
pico_pin_drop = 6.0;    // 下側 GPIO ピンの基板下面からの突き出し（実測=6, 暫定）
pico_boss_d   = 5.0;    // 四隅スタンドオフ外径
pico_boss_h   = pico_pin_drop + 0.5;  // スタンドオフ高（下ピン先端が床上 0.5mm で浮く）= 6.5
pico_screw_pilot = 2.1; // M2 セルフタップ下穴径（tray と同仕様。A1 mini 補正込みの実績値）
pico_screw_grip  = 5;   // セルフタップ効き深さ（スタンドオフ上面から）


// --- Door-fit clearances from the thumb-turn axis (origin = rosette center) ---
clear_left  = 50;   // -X to door edge/frame（実測: ~50 未満の上限。精密値は未確定）
clear_down  = 65;   // -Y to door handle（実測: ~65 未満の上限。精密値は未確定）
rosette_d   = 45;   // circular escutcheon diameter (registration only)（実測）

// --- Door mount pad（面ファスナー固定） ---
// プレートは面ファスナー（マジックテープ類）でドアに貼る。噛み合い状態の呼び厚を
// Z スタックに明示し、ペデスタル高さ（pedestal_top_z）で吸収する。ドア面基準の量
// （knob_h 等）とプレート基準の量の橋渡しはこの 1 定数だけが担う。
mount_pad_t = 6;    // 面ファスナー呼び厚（暫定。現物の噛み合い厚で確定する）

// --- Thumb-turn knob (measured; trapezoid) ---
knob_w_base = 27.8;  // width at the door (base, wider)（実測）
knob_w_top  = 25.6;  // width at the tip (narrower)（実測）
knob_t      = 3.1;   // thickness（実測）
knob_h      = 30;    // protrusion from the door（実測: 仮値 11 から大幅増→台座が背高に）
knob_engage = 10;    // socket engagement depth (< knob_h)（実測）
socket_wall = 2.0;

// --- Servo horn + pedestal ---
servo_horn_stack  = 12.1;   // 耳の下面→装着ホーンのバー下面（実測: ギアヘッド8 + ホーン込み4.1）
horn_seat_clear   = 0.3;    // ホーンバー下面とポケット底のすき間（バーはポケット深さ2.0のうち1.7嵌合）
// ソケット上面から耳の載る面までの高さ。バーがポケットに嵌合した状態で
// サーボの耳が来る位置を実測スタックから逆算する
horn_h            = servo_horn_stack + horn_seat_clear - (horn_thick + horn_clearance);  // 10.4
socket_oh         = knob_engage + socket_wall + 6;   // socket total height (18)
// サーボ耳の載る面（プレート座標）。面ファスナー厚のぶんプレート系全体がドアから
// 浮くため、その分をペデスタル高さから差し引いてホーンを設計位置へ戻す（v2 主補正）
pedestal_top_z    = (knob_h - knob_engage - mount_pad_t) + socket_oh + horn_h;  // 42.4
pedestal_wall_t   = 2.5;    // pedestal wall thickness

// --- ソケット キャプチャ壁（v2: ホーンバーの軸方向掛かりの鈍感化） ---
// バー両脇（Y 方向）の壁をポケット口からサーボ側へ延長し、バーが数 mm 浮いても
// 壁内に留まるようにする。中央はギアヘッドのドーム逃げで開ける。壁上端は 45° の
// 外開きファンネルで、ペデスタルごと下ろす組み付けの誘い込みを兼ねる。
// スナップ爪（連結用・任意）はクーポン v3 の予圧実測が確定してから追加する。
sock_wall_h    = 5;    // 壁高（バー面から。バー厚 1.7 + 浮き許容 ~3mm）
sock_wall_t    = 2.4;  // 壁厚
sock_wall_gap  = 0.1;  // 壁内面の追加すき間（ポケットの horn_clearance に上乗せ）
sock_wall_x0   = 7.5;  // 壁の内端 |x|（ドーム逃げ）。>= servo_dome_d/2 + 1
sock_funnel    = 2.0;  // 壁上端ファンネルの開き量（高さも同値 = 45°）
servo_dome_d   = 12;   // ギアヘッドのドーム外径（暫定・要実測）

// --- ソケット押さえ爪（クーポン v4 で形状確定: 横配置・浅くさび 4 本） ---
// バー先端付近の長辺側から爪を出し、返しをバー上面に被せて浅いくさびで
// 押さえ付ける。ばねの横力が坂で下向きの面圧に変換され、浮きには自己ロック
// 気味に効く。梁は本体スラブ（ノブポケットの脇の実体部）へ深く根を張る。
socket_claws      = true;
sock_claw_preload = 0.5;  // くさび予圧（v4 実測: 0.3/0.5 とも良好 → クリープ余裕で 0.5）
sock_claw_hk      = 1.2;  // 返しのバー上面への被さり量
sock_claw_face    = 0.8;  // 返し先端の垂直面（印刷丸まり対策）
sock_claw_tipc    = 0.05; // 返し先端とバー上面のすき間（先端は必ず越えられる）
sock_claw_w       = 5;    // 爪幅（バー長手方向）
sock_claw_t       = 1.2;  // 梁厚
sock_claw_x       = 12.5; // 爪の中心 |x|（バー先端寄り・壁帯の中）
sock_claw_root    = 10;   // 梁根元のローカル z（深いほど梁が長くしなやか。クーポン v4 と同等の梁長を確保しつつ、ノブポケット側壁への窓開けを最小にする値）
sock_claw_side    = 0.8;  // 爪の左右逃がし
sock_claw_back    = 1.5;  // 梁背面の撓みしろ
sock_claw_lead    = 1.6;  // 差し込みガイド高

// --- Interior extents from the axis at origin (mm) ---
// -X/-Y はドアクリアランスの硬い制約で不変。BB を収めるため +X/+Y に拡大する。
// （後続の Pico 配置・BB・トレイ定数が参照するため、依存順でここに置く）
ext_left  = 27;    // -X toward frame; <= clear_left
ext_right = 86;    // +X; BB ポケット右(76.5) + 固定ポスト + トレイ床(+X端84.5)に 1.5mm 余裕
ext_down  = 26;    // -Y toward handle; <= clear_down
ext_up    = 122.3; // +Y free; BB ポケット上端(120.55) + 余白。BB 系のカーブ逃げ +2.3 シフト
                   // (bb_off_y のアンカー変更) と同量を足し、Pico(ext_up 基準)も +2.3 の剛体
                   // シフトになるようにしてトレイ単体の形状を不変に保つ

// プレート外形（旧・箱外形と同じ footprint。壁は無いが名前は互換のため維持）
body_l = ext_left + ext_right + 2*wall;   // 115.8
body_w = ext_down + ext_up  + 2*wall;     // 153.1

// body center relative to the axis (axis sits low-left, body grows up-right)
center_x = (ext_right - ext_left) / 2;   // 28.5
center_y = (ext_up - ext_down) / 2;      // 48.15

// --- Pico placement in the +Y free space ---
// Pico の配置。pico_usb_gap は「Pico USB 端 → プレート +Y 端（旧内壁線 ext_up）の余白」で、
// USB プラグの抜き差しスペースとして維持する（壁開口は廃止済み・オープン構成）。
pico_usb_gap = 11;
pico_x = 0;
pico_y = ext_up - pico_usb_gap - pico_l/2;    // 85.8
pedestal_outer = rosette_d/2 + pedestal_wall_t + fit_clearance;  // 25.4

// ペデスタル受けカーブの半径系（BB/トレイの -Y アンカーが参照するため、依存順でここに定義。
// カーブ本体・ローブ等の残りのペデスタル定数は後段の「ペデスタルのボルトオン分離」ブロック）
pedestal_fit   = 0.3;    // フランジ⇔受けカーブの横嵌めすき間（フェーズ2でクーポン実測して確定）
ped_curb_wt    = 2.0;    // 受けカーブ壁厚
ped_base_d     = 2*(rosette_d/2 + pedestal_wall_t + fit_clearance);  // フランジ基礎円 = 筒外径 50.8
ped_curb_ri    = ped_base_d/2 + pedestal_fit;    // カーブ内半径 25.7
ped_curb_ro    = ped_curb_ri + ped_curb_wt;      // カーブ外半径 27.7

// --- Breadboard (half-size, 実測 85.5 x 54.5mm) ---
// 浅い囲い壁ポケットへ落とし込む。厚み bb_t は形状に使わない（壁高で位置決め）。
bb_l = 85.5;              // long side (along Y)
bb_w = 54.5;              // short side (along X)
bb_t = 9.6;              // 実測厚（両面テープ込み）。押さえタブのフック高がこの値に依存
bb_clearance     = 0.5;   // BB 外形 → ポケット内壁のすき間
bb_pocket_wt     = 2.0;   // ポケット壁厚
bb_pocket_wall_h = 5.0;   // ポケット壁高（BB 下部を囲って位置決め）
// BB 押さえレール（上下短辺の囲い壁を BB 上面まで立て、内側へリップで浮き止め）
bb_rail_hook  = 1.5;      // リップの内側 overhang（BB 上端短辺へのかぶさり）
bb_rail_lip_h = 1.5;      // リップの縦厚（上面テーパーで傾け差し込みガイド）
pico_bb_gap      = 4;     // Pico 右端 → ポケット外壁左のすき間（ジャンパ差込）
bb_ped_gap       = 2.35;  // ポケット外壁下端 → 受けカーブ外周のすき間

// BB 中心（ワールド座標）。ポケット外壁の左端が Pico 右端から pico_bb_gap、
// 下端が受けカーブ外周（ped_curb_ro。ペデスタル系で最も +Y に張り出す本体形状）から
// bb_ped_gap だけ離れるように置く。旧アンカーは筒外周 pedestal_outer(25.4) だったが、
// カーブ(27.7)の方が外にあり実機でトレイ床前縁が乗り上げたため、カーブ基準に変更（+2.3 シフト）。
bb_off_x = pico_x + pico_w/2 + pico_bb_gap + bb_pocket_wt + bb_clearance + bb_w/2;  // 44.25
bb_off_y = ped_curb_ro + bb_ped_gap + bb_pocket_wt + bb_clearance + bb_l/2;         // 75.3

// BB ポケット内壁の端（BB 外形＋クリアランス）。Pico すき間を保つため -X（Pico 側）は
// 動かさず、反対の +X（ツメ2つの下辺）側だけ bb_ext_farx ぶん外へ広げる。
bb_ext_farx = 2.5;   // Pico と反対側(+X)へポケット内寸を拡張する量（Pico すき間 4mm を保つ）
pocket_inner_left   = bb_off_x - bb_w/2 - bb_clearance;                 // 16.5（元通り＝gap 保持）
pocket_inner_right  = bb_off_x + bb_w/2 + bb_clearance + bb_ext_farx;   // 74.5
pocket_inner_bottom = bb_off_y - bb_l/2 - bb_clearance;                 // 32.05
pocket_inner_top    = bb_off_y + bb_l/2 + bb_clearance;                 // 118.55
// ポケット外形の端（アサート・床範囲・固定ポスト配置の基準）
pocket_outer_left   = pocket_inner_left   - bb_pocket_wt;  // 14.5（元通り）
pocket_outer_right  = pocket_inner_right  + bb_pocket_wt;  // 76.5
pocket_outer_bottom = pocket_inner_bottom - bb_pocket_wt;  // 30.05
pocket_outer_top    = pocket_inner_top    + bb_pocket_wt;  // 120.55

// --- Electronics carrier tray ---
tray_t           = 2.4;    // tray floor thickness
tray_screw_pilot = 2.1;    // M2 self-tap 下穴（tray_pilot_gauge 実測の実績値）
tray_screw_grip  = 5;      // self-tap 効き深さ
tray_screw_clear = 2.4;    // M2 shank clearance（本体床の貫通）
tray_head_d      = 4.2;    // M2 pan-head counterbore 径（本体床裏）
tray_head_h      = 1.6;    // counterbore 深さ

// トレイ天面留め：本体側ボス＋トレイ側スリーブ（旧・裏留めポストを置換）。
// ボディ床からボスを立て、トレイのスリーブが上から被さる。天面から M2 セルフタップで
// キャップ耳をボス上面へ締めてトレイを固定する。ドア面(z=0)は袋下穴で貫通させない。
tray_boss_d    = 5;                       // 本体ボス外径（Pico の pico_boss_d に倣い肉厚確保）
tray_boss_h    = tray_screw_grip + 1;     // ボス高 = 効き代5 + 底残し1 = 6（床下=ドア面を貫通しない）
boss_fit       = 0.4;                     // ボス⇔スリーブ横嵌めすき間（フェーズ2でクーポン実測して確定）
tray_sleeve_wt = 1.0;                      // スリーブ壁厚
// キャップ厚。頭ザグリ tray_head_h=1.6 + ネジ通し throat + 自己サポート・ファンネル分を含む。
// ファンネルはボア全径 tray_sleeve_id から段差なしで tray_screw_clear まで絞るので、45°以内に
// 収めるには tray_cap_t - tray_head_h - throat >= (tray_sleeve_id - tray_screw_clear)/2 が要る。
tray_cap_t     = 3.8;
tray_sleeve_id = tray_boss_d + 2*boss_fit;             // ボア径（ボス逃げ）= 5.8
tray_sleeve_od = tray_sleeve_id + 2*tray_sleeve_wt;    // スリーブ外径 = 7.8

tray_fix_gap     = 1;      // ポケット外壁 → 右スリーブのすき間
tray_fix_x_left  = -20;    // 左スリーブ列（Pico 左 -10.5 と壁 -27 の間）
tray_fix_x_right = pocket_outer_right + tray_fix_gap + tray_sleeve_od/2;  // 81.4
tray_fix_y_lo    = 42.3;   // 旧40。BB系のカーブ逃げ+2.3シフトに追従（トレイ形状不変）
tray_fix_y_hi    = 102.3;  // 旧100。同上
tray_fix_pts = [
  [tray_fix_x_left,  tray_fix_y_lo], [tray_fix_x_left,  tray_fix_y_hi],
  [tray_fix_x_right, tray_fix_y_lo], [tray_fix_x_right, tray_fix_y_hi],
];

// トレイ床 X 範囲（スリーブ外径基準）。右は +X 壁が近いのでスリーブ外周に flush（余白0）。
tray_x0 = tray_fix_x_left  - tray_sleeve_od/2 - 1;   // -24.9
tray_x1 = tray_fix_x_right + tray_sleeve_od/2;        // 85.3
tray_y0 = pocket_outer_bottom - 0.75;            // 29.3
tray_y1 = pocket_outer_top    + 0.25;            // 120.8

// ペデスタルのボルトオン分離（プレート受けカーブ＋底フランジ、天面 M2 留め）。
// トレイと同じボス/スリーブ/ファンネル構造を流用。フランジ基礎円が受けカーブに落ちて軸センタ
// リング、対角4ローブがカーブ切り欠きと噛んでサーボ反力トルクの回り止め、M2×4 は抜け止め専任。
ped_flange_t   = 2.4;    // 底フランジ厚（トレイ床と同厚＝スリーブ構造を無改造で流用）
ped_fix_r      = 30;     // 固定ボス配置半径。対角4点で -X/-Y プレート端(26/27)とトレイ床(y>=29.3)を回避
ped_fix_angles = [45, 135, 225, 315];
ped_fix_pts    = [for (a = ped_fix_angles) [ped_fix_r*cos(a), ped_fix_r*sin(a)]];
ped_curb_h     = ped_flange_t;   // カーブ高（フランジ上面と面一）
ped_lobe_w     = 10;     // フランジローブ幅（スリーブ od 7.8 を内包し、カーブ切り欠きと噛む）
// （pedestal_fit / ped_curb_wt / ped_base_d / ped_curb_ri / ped_curb_ro は BB アンカーが
//   参照するため前方の「受けカーブの半径系」ブロックで定義済み）
ped_curb_tray_gap = 1.0; // 受けカーブ外周 → トレイ床下端に要求する最小すき間（干渉ガード用）

// プレート上面リブ（手持ち時の剛性・印刷反り対策。ドア面はフラット維持）。
// 横桟はトレイ床(y>=tray_y0=29.3)とペデスタルスリーブ帯(対角 y≈17.3〜25.1)を避けた位置に置く。
plate_rib_h  = 4;            // リブ高（床上面から）
plate_rib_w  = 2;            // リブ幅
plate_rib_ys = [-14, 14];    // 横桟の y（ワールド y＝ロゼット軸基準。プレート中心基準ではない）（受けカーブとの交差は差し引きで自動処理）

// --- Sanity / clearance checks ---
assert(wall > 0, "wall must be positive");
assert(fit_clearance >= 0, "fit_clearance must be >= 0");
assert(ext_left <= clear_left, "left extent exceeds door clearance");
assert(ext_down <= clear_down, "down extent exceeds handle clearance");
// Realized outer extents: body outer edge from origin = body_l/2 - center_x (-X) and body_w/2 - center_y (-Y)
assert(body_l/2 - center_x <= clear_left, "realized left extent exceeds door clearance");
assert(body_w/2 - center_y <= clear_down, "realized down extent exceeds handle clearance");
assert(knob_w_top <= knob_w_base, "knob tapers base->top");
assert(knob_engage < knob_h, "engagement shallower than protrusion");

// --- Servo mount checks ---
assert(servo_plate_t >= 3, "耳ネジの実効噛み合い（天板厚）>= 3mm");
assert(horn_h - servo_plate_t >= 0.5, "天板下面とソケット上面のクリアランス >= 0.5mm");
assert(servo_screw_pilot < servo_plate_t + 2, "下穴径が天板に対して常識的な範囲");
assert(horn_h - servo_head_h >= 0.3, "ギアヘッド先端が回転するソケット上面に触れない（すき間 >= 0.3mm）");
assert(servo_horn_stack - horn_h >= 1.0, "ホーンバーがソケット上面より下に >= 1mm 沈んで嵌合する");
assert(rosette_d/2 + pedestal_wall_t <= ext_left, "pedestal within interior (-X)");
assert(rosette_d/2 + pedestal_wall_t <= ext_down, "pedestal within interior (-Y)");

// --- ホーンパラメータ整合チェック ---
assert(horn_arm_w_base > horn_arm_w_tip, "ホーン腕幅: 中心側 > 先端側（テーパー方向）");
assert(horn_thick + horn_clearance <= horn_h, "ホーン厚+クリアランスが割当高さ以内");
assert(horn_hub_d >= horn_arm_w_base, "ハブ径 >= 腕幅中心側（中央ポケットはハブ circle が支配）");
assert(horn_stub_d < horn_hub_d, "中心突起径 < ハブ径（突起がハブくぼみに収まる）");
assert(horn_arm_l + horn_clearance + 0.4 <= (knob_w_base + knob_t)/2 + socket_wall, "ホーンバーがソケット外形内に収まる（先端壁 >= 0.4mm）");

// --- キャプチャ壁・マウントパッド整合チェック（v2） ---
assert(knob_h - knob_engage - mount_pad_t > wall + 1, "パッド厚が厚すぎてソケット下端がプレート床に迫る");
assert(sock_wall_h <= horn_h - servo_plate_t - 0.5, "キャプチャ壁が天板下面に当たる（すき間 >= 0.5mm）");
assert(sock_wall_x0 >= servo_dome_d/2 + 1, "キャプチャ壁の内端がギアヘッドのドームに当たる");
assert(sock_wall_x0 < horn_arm_l, "壁の内端がバー先端より外（壁がバーを囲えない）");
assert(sock_funnel < sock_wall_h, "ファンネルが壁高より大きい");
assert(sock_wall_h > horn_thick + horn_clearance + 1, "壁高が浮き許容を生まない（バー厚+1mm 超が必要）");

// --- 押さえ爪の整合チェック ---
// 爪位置でのバー半幅（ポケット縁 = 爪内面の y）
sock_claw_bar_hw = horn_clearance +
  (horn_arm_w_tip + (horn_arm_w_base - horn_arm_w_tip) * (1 - sock_claw_x/horn_arm_l)) / 2;
assert(sock_claw_x + sock_claw_w/2 + sock_claw_side < horn_arm_l + horn_clearance, "爪帯がバー先端を超える");
assert(sock_claw_x - sock_claw_w/2 - sock_claw_side > sock_wall_x0, "爪帯が壁内端（ドーム逃げ）に食い込む");
assert(sock_claw_bar_hw > knob_t/2 + fit_clearance + 0.4, "爪の根元の直下がノブポケット（実体が無い）");
assert(sock_claw_root <= socket_oh, "爪の根元がソケット全高を超える");
assert(sock_claw_preload < sock_claw_hk/2, "予圧がくさび勾配に対して過大（坂が急になり自己ロックが崩れる）");

// --- Electronics tray / breadboard layout checks ---
// Pico が +Y 天井壁寄りでペデスタルをクリア
assert(pico_y - pico_l/2 > pedestal_outer, "Pico -Y 端がペデスタルに干渉");
assert(pico_y + pico_l/2 <= ext_up, "Pico +Y 端が内寸を超える");
// Pico 四隅スタンドオフ: 下ピンを床から逃がし、下穴がスタンドオフ内に収まる
assert(pico_boss_h >= pico_pin_drop, "スタンドオフ高が下ピン突出を逃がせない");
assert(pico_screw_grip < pico_boss_h, "ネジ下穴 grip がスタンドオフ高を超える");
assert(pico_boss_d > pico_screw_pilot + 1.6, "スタンドオフ肉厚が下穴に対して薄すぎる");
// BB ポケットが内寸に収まる（+X/+Y 壁・ペデスタルをクリア）
assert(pocket_outer_right <= ext_right, "BB ポケット右端がプレート端(+X)を超える");
assert(pocket_outer_top   <= ext_up,    "BB ポケット上端がプレート端(+Y)を超える");
assert(pocket_outer_bottom >= pedestal_outer, "BB ポケット下端がペデスタルに干渉");
assert(bb_rail_hook > bb_clearance, "BB レールリップの overhang がクリアランス以下（掴めない）");
assert(pocket_outer_left  >= pico_x + pico_w/2 + pico_bb_gap - 0.001, "Pico↔BB ポケットのすき間不足");
assert(tray_boss_d > tray_screw_pilot + 1.6, "ボス肉厚が下穴に対して薄すぎる");
assert(tray_screw_grip < tray_boss_h, "ネジ下穴 grip がボス高を超える（床貫通の恐れ）");
assert(tray_cap_t > tray_head_h, "キャップ厚が頭ザグリ深さ以下（頭が座らない）");
// ファンネルがボア全径→ネジ穴を 45°以内で絞れること（平らな張り出し=ブリッジを作らず塞がらない）
assert(tray_cap_t - tray_head_h - 0.3 >= (tray_sleeve_id - tray_screw_clear)/2, "ファンネルが 45°より急（自己サポート不可でネジ穴が塞がる）");
assert(tray_fix_x_right - tray_sleeve_od/2 >= pocket_outer_right, "右スリーブが BB ポケットに食い込む");
assert(tray_fix_x_right + tray_sleeve_od/2 <= ext_right, "右スリーブがプレート端(+X)を超える");
assert(tray_fix_x_left  + tray_sleeve_od/2 <= pico_x - pico_w/2, "左スリーブが Pico に食い込む");
assert(tray_fix_x_left  - tray_sleeve_od/2 >= -ext_left, "左スリーブがプレート端(-X)を超える");
// トレイ床が内寸に収まる（ドロップイン可能）
assert(tray_x1 <= ext_right && tray_x0 >= -ext_left, "トレイ床 X が内寸を超える");
assert(tray_y1 <= ext_up && tray_y0 >= -ext_down, "トレイ床 Y が内寸を超える");
assert(tray_y0 >= pedestal_outer - 1, "トレイ床下端がペデスタルに寄りすぎ");
// ペデスタル・ボルトオンの配置ガード
assert(ped_fix_r*sin(45) + tray_sleeve_od/2 <= tray_y0, "ペデスタルスリーブがトレイ床に食い込む");
assert(ped_fix_r*cos(45) + tray_sleeve_od/2 <= min(ext_left, ext_down), "ペデスタルスリーブがプレート端を超える");
assert(ped_curb_ro <= min(ext_left, ext_down) + wall - 0.2, "受けカーブがプレート端に寄りすぎ");
assert(ped_fix_r - tray_sleeve_od/2 > rosette_d/2 + fit_clearance, "ペデスタルボスがロゼット開口に食い込む");
assert(ped_lobe_w > tray_sleeve_od, "ローブ幅がスリーブ外径より細い（スリーブがローブから食み出す）");
assert(ped_flange_t < tray_boss_h, "フランジ厚がボス高以上（ボスがスリーブに届かない）");
// 受けカーブはペデスタル系で最も +Y に張り出す本体形状。トレイ床前縁が乗り上げた実機不具合
// (2026-07-17) の再発防止。体積干渉は scad/clash.ts でも検出する
assert(tray_y0 >= ped_curb_ro + ped_curb_tray_gap, "受けカーブがトレイ床に近すぎる（bb_ped_gap か ext_up を見直す）");
assert(max(plate_rib_ys) + plate_rib_w/2 < tray_y0, "横桟がトレイ床に食い込む");
assert(max(plate_rib_ys) + plate_rib_w/2 <= ped_fix_r*sin(45) - tray_sleeve_od/2, "横桟がペデスタルスリーブに食い込む");
