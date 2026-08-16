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
// 基板上にメスソケットで載せる Pico の外形（配置検証用）。
pico_l        = 51.0;
pico_w        = 21.0;
pico_h        = 1.0;

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
// サーボ耳の載る面（プレート座標）。面ファスナー厚ぶんの v2 主補正（-mount_pad_t）は
// 実機で過補正と判明（ローカル 46mm がちょうど良かった）ため撤回。補正なしに戻す。
pedestal_top_z    = (knob_h - knob_engage) + socket_oh + horn_h;  // 48.4（ローカル 46）
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

pedestal_outer = rosette_d/2 + pedestal_wall_t + fit_clearance;  // 25.4

// ペデスタル受けカーブの半径系（基板・トレイの -Y アンカーが参照するため、依存順でここに定義。
// カーブ本体・ローブ等の残りのペデスタル定数は後段の「ペデスタルのボルトオン分離」ブロック）
pedestal_fit   = 0.3;    // フランジ⇔受けカーブの横嵌めすき間（フェーズ2でクーポン実測して確定）
ped_curb_wt    = 2.0;    // 受けカーブ壁厚
ped_base_d     = 2*(rosette_d/2 + pedestal_wall_t + fit_clearance);  // フランジ基礎円 = 筒外径 50.8
ped_curb_ri    = ped_base_d/2 + pedestal_fit;    // カーブ内半径 25.7
ped_curb_ro    = ped_curb_ri + ped_curb_wt;      // カーブ外半径 27.7

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

// --- ユニバーサル基板 P-03229（秋月 C タイプ, 片面めっき） ---
// 横置き（長辺 72 を X 方向）。Pico はメスソケットで基板の上に重なるので、
// 電子部品エリアのフットプリントはこの 1 枚ぶんで足りる。
// （Z 積み上げが tray_t を、トレイ床範囲が tray_sleeve_od を参照するため、
//   受けカーブ系ではなくトレイ定数の直後＝依存順でここに置く）
pcb_l = 72;      // X 方向（長辺）
pcb_w = 47;      // Y 方向（短辺）
pcb_t = 1.6;
assert(pico_l <= pcb_l && pico_w <= pcb_w, "Pico がユニバーサル基板の外形に収まらない");
pcb_hole_d  = 3.2;   // 既製マウント穴（M2 は頭で押さえる。ネジ山は効かない）
pcb_hole_dx = 66;    // 長辺方向の穴ピッチ
pcb_hole_dy = 41;    // 短辺方向の穴ピッチ
// 基板 -Y 端(35.3) は -Y 側トレイ固定スリーブの上端(30.7+3.9) を 0.7 かわす位置。
// その固定点自体がペデスタルのフランジローブ(45°/135°, 先端 y=26.21)から
// トレイ床を逃がした結果ここまで上がっている。
pcb_ped_gap = 7.6;   // 基板 -Y 端 ⇔ 受けカーブ外周
pcb_off_y   = ped_curb_ro + pcb_ped_gap + pcb_w/2;   // 58.8
// 基板 -X 端を受けカーブ外周とほぼ同じ x（-27）に揃え、プレート -X 端を最小にする
pcb_off_x   = -27 + pcb_l/2;                          // 9
pcb_hole_pts = [for (sx = [-1, 1], sy = [-1, 1])
                 [pcb_off_x + sx*pcb_hole_dx/2, pcb_off_y + sy*pcb_hole_dy/2]];

pcb_standoff_h = 5;    // 支柱高（基板裏のハンダ足逃げ）
pcb_standoff_d = 5;    // 支柱外径（tray_boss_d に倣う）
pcb_screw_grip = 4;    // セルフタップ効き深さ（支柱高より浅く）

// 基板上の Z（積み上げ）
pcb_z0    = wall + tray_t + pcb_standoff_h;   // 基板下面 9.8
pcb_top_z = pcb_z0 + pcb_t;                   // 基板上面 11.4
pcb_stack_pico = 9.5;    // 基板上面 → Pico 上面（メスソケット 8.5 + Pico 1.0）
pcb_stack_usb  = 12.0;   // 基板上面 → USB コネクタ上端
pcb_stack_tall = 16.0;   // 基板上面 → 最高部品（TO-220 立て）上端
pcb_stack_low  = 3.0;    // 基板上面 → 低背部品（抵抗・ダイオード）上端

tray_fix_x_left  = -22;
tray_fix_x_right = 40;
// -Y 側の下限を決めるのはペデスタルのフランジローブ（45°/135°）。ローブ先端円は
// (±21.21, 21.21) 中心・半径 ped_lobe_w/2=5 なので上端が y=26.21 まで来る。トレイ床
// (tray_y0 = ここ - 3.9 - 0.1) がこれに 0.3 のマージンで乗らない下限は y=30.513。
// 採用値 30.7 の余裕は 0.187 しかないので、この 3 定数はどれも動かすと assert が鳴る。
// スリーブ中心間もローブ半幅込みの下限 9.4 に対し 9.519（余裕 0.119）とやはり詰まっている。
tray_fix_y_lo    = 30.7;   // 基板 -Y 端(35.3) の下
tray_fix_y_hi    = 86.9;   // 基板 +Y 端(82.3) の上
tray_fix_pts = [
  [tray_fix_x_left,  tray_fix_y_lo], [tray_fix_x_left,  tray_fix_y_hi],
  [tray_fix_x_right, tray_fix_y_lo], [tray_fix_x_right, tray_fix_y_hi],
];
tray_x0 = pcb_off_x - pcb_l/2 - 0.5;                  // -27.5
tray_x1 = pcb_off_x + pcb_l/2 + 0.5;                  // 45.5
tray_y0 = tray_fix_y_lo - tray_sleeve_od/2 - 0.1;     // 26.7
tray_y1 = tray_fix_y_hi + tray_sleeve_od/2 + 0.1;     // 90.9
tray_ped_notch_r = ped_curb_ro + 1.3;                 // 29。床が受けカーブをまたぐ逃げ

// --- サーボ上端（カバー天井の根拠） ---
servo_top_z = pedestal_top_z + servo_body_h;   // 70.9

// ペデスタルのボルトオン分離（プレート受けカーブ＋底フランジ、天面 M2 留め）。
// トレイと同じボス/スリーブ/ファンネル構造を流用。フランジ基礎円が受けカーブに落ちて軸センタ
// リング、対角4ローブがカーブ切り欠きと噛んでサーボ反力トルクの回り止め、M2×4 は抜け止め専任。
ped_flange_t   = 2.4;    // 底フランジ厚（トレイ床と同厚＝スリーブ構造を無改造で流用）
ped_fix_r      = 30;     // 固定ボス配置半径。対角4点で -X/-Y プレート端とトレイ床(y>=26.7)を回避
ped_fix_angles = [45, 135, 225, 315];
ped_fix_pts    = [for (a = ped_fix_angles) [ped_fix_r*cos(a), ped_fix_r*sin(a)]];
ped_curb_h     = ped_flange_t;   // カーブ高（フランジ上面と面一）
ped_lobe_w     = 10;     // フランジローブ幅（スリーブ od 7.8 を内包し、カーブ切り欠きと噛む）
// （pedestal_fit / ped_curb_wt / ped_base_d / ped_curb_ri / ped_curb_ro は基板・トレイの
//   -Y アンカーが参照するため前方の「受けカーブの半径系」ブロックで定義済み）
ped_curb_tray_gap = 1.0; // 受けカーブ外周 → トレイ床下端に要求する最小すき間（干渉ガード用）

// プレート上面リブ（手持ち時の剛性・印刷反り対策。ドア面はフラット維持）。
// 横桟はプレート全幅に走るのでカバーの -X/+X 側壁の真下を貫いてしまい、カバーが座らない。
// よって全廃し、剛性は M2 留めされたカバーが肩代わりする。残るのはカバー固定ボス
// （cover_ear_pts の4点。-Y 側の2隅＋±X 壁上の2点）を逃がした外周リブ（＝閉じた一周
// ではなく4本の直線区間）で、これがカバー裾の外面を受ける（plate_margin 参照。
// 詳細は body.scad の plate_ribs() 参照）。
plate_rib_h  = 4;            // リブ高（床上面から）
plate_rib_w  = 2;            // リブ幅
plate_rib_ys = [];           // 横桟なし（ワールド y のリスト。空＝外周リブのみ）

// --- カバー内面（プレート外形の起点。カバー本体は Task 3 の cover.scad） ---
cover_wall  = 2.0;
cover_clear = 1.0;    // 内面 ⇔ 中身のすきま
cover_x0 = -(ped_curb_ro + cover_clear);   // -28.7（受けカーブが支配）
cover_x1 = tray_x1 + cover_clear;          // 46.5
cover_y0 = -(ped_curb_ro + cover_clear);   // -28.7
cover_y1 = tray_y1 + cover_clear;          // 91.9
// 外形角の丸め半径。カバー裾（cover.scad の cover_outline_2d / cover_ear_webs）と
// プレート外形（body.scad の plate_outline_2d）が同じ offset(r) offset(-r) の書き方で
// 共有する。プレートはカバー裾を追従する輪郭なので、両者がずれると耳とラグの位置
// 関係（下のラグ分離ガードの前提）が崩れる。1 箇所で持つ。
cover_round_r = 2;

// カバーの高さと勾配。天面をベッドに伏せて刷るので屋根に水平な段を作らない
// （段は第 1 層より下に宙で現れて垂れる）。+Y への単一勾配 45°。
cover_head_clear = 2.0;                                    // サーボ上端 ⇔ 内面天井
cover_inner_top  = servo_top_z + cover_head_clear;         // 72.9
// 斜面で壁厚 cover_wall を「垂直」に確保するには、天面との垂直差が √2 倍要る。
// 平天面の厚みは cover_wall*sqrt(2) = 2.83 になる（ベッド面なので厚い方が都合が良い）。
cover_top_z      = cover_inner_top + cover_wall*sqrt(2);   // 75.73
// カバー内面とトレイ固定スリーブ天面に要求する最小すきま。勾配開始 y の下限と
// cover_test.scad の検証の両方がこの 1 個を参照する（別々に書くと値がずれる。
// 実際に Ruling 8 で 0.5 と 1.0 の2つの値を書いて食い違わせた反省）。
cover_tray_gap = 1.0;

// 勾配の開始 y。手置き。下の2本の assert（Sanity セクション）が下限を守る。
//  - ペデスタル域を全高で覆う下限: ped_curb_ro + cover_clear = 28.7
//  - トレイ +Y 固定スリーブの天面をかわす下限:
//    (tray_fix_y_hi + tray_sleeve_od/2) - (cover_inner_top - (wall+tray_boss_h+tray_cap_t) - cover_tray_gap)
//    = 31.1（スリーブは中心 tray_fix_y_hi から半径ぶん +Y に張り出すので、最外点 90.8 で
//    評価する。式は Ruling 10 で assert 側へ移した参考値であり、この行の数値をコードが
//    読むことはない）
// 導出式のままだと下限とそれを検証する assert が同じ式になって恒真化するうえ、浮動小数の
// 等号ぎりぎりで丸め次第で落ちるため、値は手で置いて 0.1 の余裕を持たせてある。
cover_slope_y0 = 31.2;
// 屋根内面の高さ（y の関数）。干渉チェックの assert が参照する。
function roof_in_z(y) = cover_inner_top - max(0, y - cover_slope_y0);
// 背高部品（pcb_stack_tall）を置ける +Y 側の限界。roof_in_z(y) >= pcb_top_z + pcb_stack_tall + 2
// を y について解いたもの。これより +Y は屋根が下がるので低背部品だけ。基板は 82.3 まで
// あるので、+Y 端 7.6mm（= 82.3 - pcb_tall_y_max）ほどは 16mm 級を置けない帯になる。
// 注意: これとは別に、パネル取付スイッチのキープアウト帯（x -6.8〜4.8, y 32.5〜59.1。
// pcb_tall_y_max=74.7 のずっと内側。下記 sw_pt 周辺のコメント参照）が独立に存在する。
// この帯は基準が違う（スイッチ本体の掃引と部品の当たり）ので、pcb_tall_y_max だけ見て
// 「この y より内側なら 16mm 級を置ける」と判断しないこと。
pcb_tall_y_max = cover_slope_y0 + cover_inner_top - (pcb_top_z + pcb_stack_tall) - 2;  // 74.7
assert(pcb_tall_y_max > pcb_off_y - pcb_w/2, "背高部品を置ける帯が基板上に存在しない");

// 開口: USB 切欠き（+X 壁）
cover_usb_y = pcb_off_y;                    // 58.8
cover_usb_z = pcb_top_z + pcb_stack_pico + (pcb_stack_usb - pcb_stack_pico)/2;  // 22.15
cover_usb_w = 14;    // Y 方向
cover_usb_h = 10;    // Z 方向

// 開口: LED 窓（屋根の斜面。素通し穴）。y=79.8 での屋根内面 z = roof_in_z(79.8) = 24.3
// （基板上面 11.4 から 12.9mm。低背 LED なら余裕）
cover_led_pt = [pcb_off_x - 24, pcb_off_y + 21];   // (-15, 79.8)
cover_led_d  = 6;

// --- パネル取付スイッチ PS21B-1（秋月 P-04583, モーメンタリ OFF-(ON)） ---
sw_thread_d = 11.5;   // ネジ部外径（実測 2026-08-16）
sw_panel_d  = 12.0;   // 取付穴（すきま 0.5。印刷公差込み）
sw_flange_d = 18.7;   // フランジ外径
sw_seat_d   = 19.0;   // 座面として平面が要る径
sw_thread_l = 8.3;    // ネジ部長さ（挟めるパネル厚の上限）
sw_depth    = 26;     // パネル面より内側の奥行き（端子先端まで）
sw_cap_d    = 14;     // キャップ外径
sw_cap_h    = 7.6;    // パネル面より外への突出
sw_body_d   = sw_thread_d;   // 本体（掃引体）の外径。実測が無いのでネジ部外径を保守的に流用
sw_pt       = [-1, 55];   // 屋根斜面上の取付中心（xy）
// 取付点の屋根外面 z と、法線方向へ sw_depth 伸ばした本体先端の z（軸上）
sw_face_z = cover_top_z - (sw_pt[1] - cover_slope_y0);   // 51.93
sw_tip_z  = sw_face_z - sw_depth*cos(45);                // 33.54
// 基板側 keep-out: 本体を φsw_body_d の円柱として法線方向に sw_depth 掃引すると、
// ワールド x -6.8〜4.8 / y 32.5〜59.1 を通り、最下点は (x -1, y 40.7, z 29.48)。
// x/y の帯は sw_pt・sw_depth・45° 勾配だけで決まり cover_slope_y0 に依存しないが、
// z（29.48）は cover_slope_y0 のぶんだけ底上げされている（cover_slope_y0 を手置きの
// 定数にした Ruling 10 の値 31.2 に対応。以前の値からのズレはそのつど cover_slope_y0
// の変化ぶんだけ連動する）。
// 軸上の先端 z（33.54）ではなく、この最下点が基板の部品と当たるかを決める。
// この帯には pcb_stack_tall 級（上端 27.4）の部品を置かないこと。Pico スタック
// （上端 20.9）なら 8.58mm の余裕がある。cover_test.scad の assert が下限を守る。

// --- プレート外形 ---
// カバー裾の外面を外周リブの内面で受ける。プレート端 = 裾外面 + リブ幅 + 嵌合すきま。
cover_lip_fit = 0.3;
plate_margin  = plate_rib_w + cover_lip_fit;   // 2.3
plate_x0 = cover_x0 - cover_wall - plate_margin;   // -33.0
plate_x1 = cover_x1 + cover_wall + plate_margin;   //  50.8
plate_y0 = cover_y0 - cover_wall - plate_margin;   // -33.0
plate_y1 = cover_y1 + cover_wall + plate_margin;   //  96.2
body_l   = plate_x1 - plate_x0;        // 83.8
body_w   = plate_y1 - plate_y0;        // 129.2
center_x = (plate_x0 + plate_x1)/2;    // 8.9
center_y = (plate_y0 + plate_y1)/2;    // 31.6
// カバー固定の耳／ラグ。-Y 側は裾の外角から対角方向へ各軸 cover_ear_off ずらし、
// 円（tray_sleeve_od）が裾の角にちょうど接するようにする。
// +Y 側は角ではなく ±X 壁の y = tray_fix_y_hi（トレイ +Y 固定点と同じ y）に置く。
// +Y の角に置くと耳の天面（12.2）がその y の屋根（10.23）を突き抜け、天面をベッドに
// 伏せる印刷でベッドから 63mm の孤立島になって刷れない。y = 86.9 なら屋根外面が 20.03
// なので耳は壁の高さに収まり、しかも直線の壁には角丸めの引っ込みが無いので耳の円が
// 裾外面へ 1.1mm 食い込み、ウェブ無しで裾と繋がる（cover.scad の cover_ear_webs 参照）。
cover_ear_off = 2.8;
cover_ear_pts = [
  [cover_x0 - cover_wall - cover_ear_off, cover_y0 - cover_wall - cover_ear_off],
  [cover_x1 + cover_wall + cover_ear_off, cover_y0 - cover_wall - cover_ear_off],
  [cover_x0 - cover_wall - cover_ear_off, tray_fix_y_hi],
  [cover_x1 + cover_wall + cover_ear_off, tray_fix_y_hi],
];  // (-33.5, -33.5) / (51.3, -33.5) / (-33.5, 86.9) / (51.3, 86.9)
plate_lug_d = 9;   // プレート側ラグの円径（スリーブ od 7.8 を内包）
assert(plate_lug_d > tray_sleeve_od, "ラグ径がスリーブ外径以下");
assert(max([for (p = cover_ear_pts) max(-p[0], -p[1])]) + plate_lug_d/2
       <= min(clear_left, clear_down), "固定ラグがドアクリアランスを超える");
// cover_ear_off の下限・上限ガード（対）。
// 下限: 「円（tray_sleeve_od）が裾の角にちょうど接する」という上のコメントの設計意図。
// cover_ear_off が小さすぎるとラグ内のスリーブが裾の角に食い込む。
assert(cover_ear_off*sqrt(2) >= tray_sleeve_od/2,
       "cover_ear_off が小さく、ラグ内のスリーブが裾の角に食い込む");
// 上限: cover_ear_off が大きすぎるとラグが本体矩形の丸め offset で橋渡しされず、
// 4枚の独立した円盤に分離してしまう（offset(r=2) offset(r=-2) は非連結形状を繋がない）。
assert((cover_ear_off - plate_margin + cover_round_r)*sqrt(2) - cover_round_r < plate_lug_d/2,
       "ラグが本体矩形から離れて別体になる");
// -Y の耳は角丸めのぶん裾から浮くので cover_ear_webs() が橋を架ける。その橋はリブ天面より
// 上の z 帯（wall + plate_rib_h + fit_clearance 〜 wall + tray_boss_h + tray_cap_t）に張るので、
// リブが高くなると帯が消えて linear_extrude が負の高さになり、耳が黙って分離する。
assert(plate_rib_h + fit_clearance < tray_boss_h + tray_cap_t,
       "リブが高すぎて耳ウェブの z 帯が消える");
// +Y の耳（cover_ear_pts の y = tray_fix_y_hi、実体は m2_sleeve_solid() = φ tray_sleeve_od）
// は屋根勾配の途中に直接載る。耳の天面（wall + tray_boss_h + tray_cap_t）が、耳の半径ぶん
// +Y に張り出した最外点（tray_fix_y_hi + tray_sleeve_od/2）でもその y での屋根外面より
// 上に出ると、伏せ印刷時にベッドから浮いた孤立島になり刷れない（Task 3 で踏んだ地雷）。
// 将来 tray_fix_y_hi を +Y へ動かす変更に対するガード。中心 tray_fix_y_hi だけで見て
// 最外点を見落とす失敗パターンは Ruling 9 参照（この assert 自体も一度その形で書いていた）。
// 支配関係の注記: 現在値では下の assert（屋根がトレイ +Y 固定スリーブの天面に当たる。
// cover_tray_gap ぶんの追加マージン込み）の方が必ず先に落ちるため、この assert は単独では
// 発火しない（cover_top_z 基準 vs cover_inner_top+cover_tray_gap 基準の差ぶん、この assert
// の方が常に緩い）。それでも削除しない: メッセージが「耳が孤立島になる」という cover.scad
// 側の固有の破綻モードを名指ししており、下の assert（「屋根がスリーブ天面に当たる」という
// 干渉そのもの）とは診断上の役割が違う。将来どちらかを変更・削除する際の判断材料として残す。
assert(cover_top_z - (tray_fix_y_hi + tray_sleeve_od/2 - cover_slope_y0)
       >= wall + tray_boss_h + tray_cap_t,
       "+Y の耳の天面が屋根を突き抜ける（伏せ印刷で孤立島になる）");
// cover_slope_y0（手置き定数）が守るべき2つの下限。cover_slope_y0 自体を導出式にすると
// 下限とそれを検証する assert が同じ式になって恒真化するので、ここで独立に検証する
// （Ruling 10）。
assert(cover_slope_y0 >= ped_curb_ro + cover_clear,
       "勾配開始がペデスタル域に食い込む");
// スリーブは中心 tray_fix_y_hi ではなく半径ぶん +Y に張り出した最外点で評価する
// （中心だけを見て実干渉を1回見落とした。clash.ts の cover×tray ペアが検出した）。
assert(roof_in_z(tray_fix_y_hi + tray_sleeve_od/2)
       >= wall + tray_boss_h + tray_cap_t + cover_tray_gap,
       "屋根がトレイ +Y 固定スリーブの天面に当たる");

// 旧 ext_* は「軸原点から内寸の端まで」の意味。既存 assert と互換のため導出で残す。
ext_left  = -plate_x0 - wall;
ext_right =  plate_x1 - wall;
ext_down  = -plate_y0 - wall;
ext_up    =  plate_y1 - wall;

// --- Sanity / clearance checks ---
assert(wall > 0, "wall must be positive");
assert(fit_clearance >= 0, "fit_clearance must be >= 0");
assert(ext_left <= clear_left, "left extent exceeds door clearance");
assert(ext_down <= clear_down, "down extent exceeds handle clearance");
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

// --- Electronics tray layout checks ---
assert(tray_boss_d > tray_screw_pilot + 1.6, "ボス肉厚が下穴に対して薄すぎる");
assert(tray_screw_grip < tray_boss_h, "ネジ下穴 grip がボス高を超える（床貫通の恐れ）");
assert(tray_cap_t > tray_head_h, "キャップ厚が頭ザグリ深さ以下（頭が座らない）");
// ファンネルがボア全径→ネジ穴を 45°以内で絞れること（平らな張り出し=ブリッジを作らず塞がらない）
assert(tray_cap_t - tray_head_h - 0.3 >= (tray_sleeve_id - tray_screw_clear)/2, "ファンネルが 45°より急（自己サポート不可でネジ穴が塞がる）");
// ペデスタル・ボルトオンの配置ガード
assert(ped_fix_r*sin(45) + tray_sleeve_od/2 <= tray_y0, "ペデスタルスリーブがトレイ床に食い込む");
// -X/-Y 端に一番近づくのはスリーブ（od 7.8）ではなくフランジのローブ（幅 ped_lobe_w=10）。
// ローブは線分 p/2→p の全長に太さ ped_lobe_w で存在するので、外への張り出しは
// ped_lobe_w/2 = 5 で見る。スリーブ半径 3.9 で見ると 1.1mm 見落とす（トレイ側の
// 「ローブに食い込む」assert と同じ盲点）。
assert(ped_fix_r*cos(45) + ped_lobe_w/2 <= min(ext_left, ext_down), "ペデスタルのフランジローブがプレート端を超える");
assert(ped_curb_ro <= min(ext_left, ext_down) + wall - 0.2, "受けカーブがプレート端に寄りすぎ");
assert(ped_fix_r - tray_sleeve_od/2 > rosette_d/2 + fit_clearance, "ペデスタルボスがロゼット開口に食い込む");
assert(ped_lobe_w > tray_sleeve_od, "ローブ幅がスリーブ外径より細い（スリーブがローブから食み出す）");
assert(ped_flange_t < tray_boss_h, "フランジ厚がボス高以上（ボスがスリーブに届かない）");

// --- 基板・トレイのレイアウトチェック ---
// ここに置く assert は「入力パラメータを手で変えたときに落ちうる」ものだけにする。
// 同じ定義式から導いた値どうしの比較（例: tray_x0 <= pcb -X 端。tray_x0 の定義がまさに
// それ -0.5）は恒真でガードとして働かないので置かない。
//
// 基板 -Y 端を受けカーブから 1mm 以上逃がす、という設計意図の表明。
// pcb_off_y の定義に代入すると pcb_ped_gap >= 1 に縮退するので、そのまま直に書く。
assert(pcb_ped_gap >= 1, "基板 -Y 端が受けカーブに近すぎる");
// -X 端はカバー内面（受けカーブ支配の -28.7）に対して独立に置いているので実効ガード。
// +X 側は cover_x1 が tray_x1 = 基板 +X 端 +0.5 から導出＝恒真なので置かない。
assert(pcb_off_x - pcb_l/2 >= cover_x0, "基板 -X 端がカバー内面を超える");
assert(pcb_screw_grip < pcb_standoff_h, "支柱の下穴 grip が支柱高を超える");
assert(pcb_standoff_d > tray_screw_pilot + 1.6, "支柱の肉厚が下穴に対して薄すぎる");
assert(tray_fix_y_lo + tray_sleeve_od/2 <= pcb_off_y - pcb_w/2, "-Y 固定スリーブが基板に食い込む");
assert(tray_fix_y_hi - tray_sleeve_od/2 >= pcb_off_y + pcb_w/2, "+Y 固定スリーブが基板に食い込む");
// 基板支柱と固定スリーブはどちらも tray() の union の中なので、食い込んでも融合して
// 黙って印刷される（clash.ts は部品「間」しか見ないので検出できない）。ここで殺す。
assert(min([for (s = pcb_hole_pts, t = tray_fix_pts) norm(s - t)])
       >= (pcb_standoff_d + tray_sleeve_od)/2 + 0.5,
       "基板支柱がトレイ固定スリーブに食い込む");
assert(min([for (p = tray_fix_pts) norm(p)]) >= ped_curb_ro + tray_sleeve_od/2 + 0.5,
       "固定スリーブが受けカーブに食い込む");
// トレイ固定スリーブとペデスタル底フランジの共倒れガード。
// 旧レイアウトで実際に 4.36mm まで接近して食い込んでいたので必ず入れる。
// トレイスリーブに先に当たるのはペデスタルの「スリーブ」ではなく「ローブ」。ローブは
// 線分 p/2→p の全長に太さ ped_lobe_w=10 で存在し、z 帯もスリーブと確実に重なるので、
// 必要な中心間距離は od/2 + ped_lobe_w/2。スリーブ外径だけで見ると 0.6mm 見落とす。
assert(min([for (t = tray_fix_pts, q = ped_fix_pts) norm(t - q)])
       >= tray_sleeve_od/2 + ped_lobe_w/2 + 0.5,
       "トレイ固定スリーブがペデスタルのフランジローブに食い込む");
// 同じローブが y 方向でトレイ床の -Y 端にも当たる（先端円の上端 y = 21.21 + 5）。
assert(tray_y0 >= ped_fix_r*sin(45) + ped_lobe_w/2 + 0.3, "トレイ床 -Y 端がペデスタルのフランジローブに乗る");
assert(tray_ped_notch_r >= ped_curb_ro + ped_curb_tray_gap, "トレイ床の逃げが受けカーブに近すぎる");
// -X/-Y 側だけ実効（+X/+Y 側は cover_x1/cover_y1 が tray_x1/tray_y1 から導出＝恒真）。
assert(tray_x0 >= cover_x0, "トレイ床 -X 端がカバー内面を超える");
assert(tray_y0 >= cover_y0, "トレイ床 -Y 端がカバー内面を超える");
// --- プレートのドアクリアランス ---
assert(-plate_x0 <= clear_left, "プレート -X 端がドアクリアランスを超える");
assert(-plate_y0 <= clear_down, "プレート -Y 端がドアクリアランスを超える");
