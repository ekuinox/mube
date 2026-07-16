# オープンベースプレート化＋ペデスタルのボルトオン分離 実装プラン

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 外周壁・蓋を全廃して本体を「ドアに貼る1枚のベースプレート」にし、ロゼット台座（ペデスタル）を天面 M2 留めのボルトオン部品に分離する。

**Architecture:** プレートは床＋上面リブ＋受けカーブ＋固定ボス群（トレイ4・ペデスタル4）。ペデスタルは底フランジ（基礎円＋対角4ローブ）＋筒＋サーボ天板＋固定スリーブ4個の単品。フランジが受けカーブに落ちて軸センタリング、ローブがカーブ切り欠きと噛んでサーボ反力トルクの回り止め、M2×4 は抜け止め専任。トレイで実機検証済みのボス/スリーブ/ファンネル構造をそのまま流用する。

**Tech Stack:** OpenSCAD（nix devShell 内）。検証は `./test/render.sh` / `./build.sh` の Status: NoError と `params.scad` の assert。

## spec からの設計変更（詳細設計で確定した3点）

1. **受け「ポケット」→受け「カーブ（土手リング）」**: プレートは 2.4mm 厚で深さ 2mm のポケットを掘れない（床が 0.4mm になる）。床上面に立てたリング（高さ=フランジ厚）で同じ位置決め機能を実現する。`pedestal_top_z` 不変の性質は「フランジがプレート上面に載り、ペデスタルのローカル高さを `pedestal_top_z - wall` にする」ことで維持。
2. **固定 3 点 → 対角 4 点（45°/135°/225°/315°, 半径 30）**: 等配3点だと必ず -X/-Y 端（プレート縁）かトレイ床（y≥27）に食い込む。対角4点はスリーブ外縁が原点から 25.1mm で全方向セーフ（トレイ床 27、縁 26/27）。
3. **回り止めノッチ×タブ → カーブ切り欠き×フランジローブ**: スリーブを載せるローブがカーブを横切るため、どのみちカーブに切り欠きが要る。切り欠き幅を「ローブ幅＋嵌め合い」にして、ローブ自体を回り止めタブに兼用する（部品・形状を追加しない）。

## Global Constraints

- `openscad` は nix devShell 内のみ。素の呼び出しは `nix develop -c openscad ...`、`.sh` はそのまま実行可（自己再突入する）。
- ソースコメントは日本語で、説明を十分に足す。
- ドア面（`z=0`）に穴・ザグリを出さない（ロゼット開口のみ。ボス下穴は袋のまま）。
- ペデスタル天板上面のワールド高さ `pedestal_top_z = 48.4` を維持（サーボ/ホーン/ソケット噛み合いの既存 asserts を全部生かす）。
- スリーブは必ずトレイと同じファンネル構造（ボア全径→`tray_screw_clear` へ 45°以内で絞る。平らな張り出し禁止＝穴が塞がる実機不具合の再発防止）。
- `build/` と `*.stl` は非コミット。
- 各タスク完了時点で `./test/render.sh` / `./build.sh` が通る状態を保つ（途中で壊さない）。

## File Structure

- `scad/hardware.scad` — 共有モジュール `m2_boss()` / `m2_sleeve_solid()` / `m2_sleeve_cuts()` を新設、`tray_mount_bosses()` を委譲化、`ped_mount_bosses()` 追加、`usb_cutout()` 削除。
- `scad/tray.scad` — スリーブ生成を共有モジュール使用にリファクタ（形状不変）。
- `scad/body.scad` — 箱シェル・USB 開口・サーボカットを除去し、プレート（床＋カーブ＋ボス＋リブ）に置換。`mount_plate.scad` は削除して内容を統合。
- `scad/pedestal.scad` — 新設。フランジ＋筒＋天板＋スリーブの単品部品。
- `scad/params.scad` — 壁/蓋/USB/LED 系パラメータ削除、`ped_*` パラメータ・asserts 追加。
- `scad/smartlock.scad` — `lid`/`asm_lid` 削除、`pedestal`/`asm_pedestal`/`ped_mount_coupon` 追加、`mount_coupon` をペデスタル対象に変更。
- 削除: `scad/lid.scad`, `scad/layout_check.scad`, `scad/mount_plate.scad`, `test/lid_test.scad`, `test/mount_plate_test.scad`。
- 追加: `test/pedestal_test.scad`。更新: `test/hardware_test.scad`, `test/params_test.scad`, `build.sh`, `viewer/serve.py`, `viewer/index.html`, `README.md`。

---

### Task 1: M2 ボス/スリーブの共有モジュール化（形状不変リファクタ）

トレイで実機検証済みのボス・スリーブ・ファンネル形状を、ペデスタルからも使えるよう `hardware.scad` へ抽出する。このタスクでは形状を一切変えない。

**Files:**
- Modify: `scad/hardware.scad`（`tray_mount_bosses` を委譲化＋新モジュール3つ）
- Modify: `scad/tray.scad`（スリーブ solid/cuts を共有モジュール呼び出しに）

**Interfaces:**
- Produces:
  - `m2_boss()`: 原点に置く1本のボス（φ`tray_boss_d`×`tray_boss_h`、上面から袋下穴）。呼び出し側が translate する。
  - `m2_sleeve_solid()`: 原点に置く1個のスリーブ外形（φ`tray_sleeve_od`×`tray_boss_h + tray_cap_t` の円柱）。union 側で使う。
  - `m2_sleeve_cuts()`: 同じ原点基準のスリーブ内側カット一式（ボア／ファンネル／throat／頭ザグリ）。difference 側で使う。
  - `tray_mount_bosses()`: 従来通り（内部で `m2_boss()` を使うだけ）。

- [ ] **Step 1: hardware.scad — 共有モジュールを追加し tray_mount_bosses を委譲化**

`scad/hardware.scad` の `tray_mount_bosses` モジュール全体（「// トレイを本体天面（内側）から留めるための本体側ボス。」のコメントから閉じ括弧まで）を、次に置き換える。

```openscad
// M2 セルフタップ用ボス1本（原点基準・呼び出し側で translate）。床上面に立て、上面から
// tray_screw_pilot の袋下穴を tray_screw_grip 深さで彫る（下=ドア面を貫通しない）。
module m2_boss() {
  difference() {
    cylinder(d = tray_boss_d, h = tray_boss_h);
    translate([0, 0, tray_boss_h - tray_screw_grip])
      cylinder(d = tray_screw_pilot, h = tray_screw_grip + 0.1);
  }
}

// M2 スリーブ1個の外形（原点基準）。union 側で使い、内側は m2_sleeve_cuts() で彫る。
// ボスに被さって XY 位置決めし、天面から M2 でキャップを締める（トレイで実機検証済みの構造）。
module m2_sleeve_solid() {
  cylinder(d = tray_sleeve_od, h = tray_boss_h + tray_cap_t);
}

// M2 スリーブ1個の内側カット一式（原点基準）。difference 側で使う。
// キャップ裏はボア全径から段差なしで絞る自己サポート・ファンネル。平らな張り出し（ブリッジ）を
// 一切作らないので、床下向き印刷でもネジ穴が垂れて塞がらない（実機で塞がった対策）。throat=0.3mm。
module m2_sleeve_cuts() {
  // ボス逃げボア（下端貫通〜ボス収容, φ tray_sleeve_id 一定）
  translate([0, 0, -0.1])
    cylinder(d = tray_sleeve_id, h = tray_boss_h + 0.1);
  // 自己サポート・ファンネル（ボア全径 tray_sleeve_id → 上へ tray_screw_clear へ絞る）
  translate([0, 0, tray_boss_h - 0.01])
    cylinder(d1 = tray_sleeve_id, d2 = tray_screw_clear,
             h = tray_cap_t - tray_head_h - 0.3);
  // ネジ通し throat（ファンネル上端〜天面。頭ザグリと重ねる）
  translate([0, 0, tray_boss_h + tray_cap_t - tray_head_h - 0.3 - 0.01])
    cylinder(d = tray_screw_clear, h = tray_head_h + 0.3 + 0.2);
  // 頭ザグリ（天面から）
  translate([0, 0, tray_boss_h + tray_cap_t - tray_head_h])
    cylinder(d = tray_head_d, h = tray_head_h + 0.2);
}

// トレイを本体天面（内側）から留めるための本体側ボス。tray_fix_pts の各点に床上面
// （z=wall）から立てる。トレイのスリーブが被さり、天面から M2 セルフタップで固定する。
module tray_mount_bosses() {
  for (p = tray_fix_pts)
    translate([p[0], p[1], wall]) m2_boss();
}
```

- [ ] **Step 2: tray.scad — スリーブを共有モジュール呼び出しに置換**

`scad/tray.scad` の union 内スリーブ solid ブロック（「// 固定スリーブ solid（ボア/ネジ穴は下の difference で彫る）。」のコメントから `cylinder(d = tray_sleeve_od, h = tray_boss_h + tray_cap_t);` まで）を、次に置き換える。

```openscad
      // 固定スリーブ solid（内側は下の difference で彫る）。床下面 z=0 から立てるので床プレート
      // (0..tray_t) と重複するが union で合体するため問題ない（z=tray_t にするとスリーブが床面で
      // 分断される）。形状は hardware.scad の共有モジュール（トレイ/ペデスタル共用）。
      for (p = tray_fix_pts)
        translate([p[0], p[1], 0]) m2_sleeve_solid();
```

続けて difference 内のスリーブカット一式（「// 固定スリーブのボス逃げボア（床貫通〜ボス収容）＋キャップのネジ通し＋頭ザグリ（天面から）。」のコメントブロックから、頭ザグリ cylinder を含む for ループの閉じ `}` まで）を、次に置き換える。

```openscad
    // 固定スリーブの内側カット（ボア/ファンネル/throat/頭ザグリ。hardware.scad の共有モジュール）
    for (p = tray_fix_pts)
      translate([p[0], p[1], 0]) m2_sleeve_cuts();
```

- [ ] **Step 3: render で形状が壊れていないことを確認**

Run: `./test/render.sh scad/tray.scad`
Expected: `OK: /tmp/tray.stl`、WARNING/ERROR/assert 失敗なし。

Run: `./build.sh`
Expected: `All parts built to build/`（全パート Status: NoError）。

- [ ] **Step 4: コミット**

```bash
git add scad/hardware.scad scad/tray.scad
git commit -m "refactor(scad): M2ボス/スリーブを共有モジュール化（形状不変）

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 2: 壁・蓋・USB 開口の全廃（オープンプレート化）

body から箱シェルを外し、lid と関連パラメータ・テスト・ビルド対象を消す。ペデスタルはまだ一体のまま（Task 3 で分離）。

**Files:**
- Modify: `scad/body.scad`（箱シェル・USB 削除）
- Modify: `scad/params.scad`（壁/蓋/USB/LED 系削除）
- Modify: `scad/hardware.scad`（`usb_cutout()` 削除）
- Modify: `scad/tray.scad`（USB マーカーのコメントのみ更新）
- Modify: `scad/smartlock.scad`, `build.sh`, `viewer/serve.py`, `viewer/index.html`, `test/hardware_test.scad`, `test/params_test.scad`
- Delete: `scad/lid.scad`, `scad/layout_check.scad`, `test/lid_test.scad`

**Interfaces:**
- Consumes: `mount_plate()`（既存。床＋一体ペデスタル。Task 3 で置換されるまで温存）。
- Produces: `body()` = `mount_plate()` ＋ `tray_mount_bosses()` − サーボポケット（壁なし）。パート集合から `lid` / `asm_lid` が消える。

- [ ] **Step 1: body.scad — 箱シェルと USB を除去**

`scad/body.scad` の中身全体を次に置き換える（`rounded_box` モジュールも削除）。

```openscad
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
```

- [ ] **Step 2: params.scad — 壁/蓋/USB/LED 系パラメータの削除と整理**

以下を削除する:
- `box_corner_r`（7行目）と `lid_lip_h`（8行目）
- `usb_w` / `usb_h` / `usb_connector_h`（52〜54行目、コメント込み）
- `led_hole_d` / `button_hole_d` / `led_btn_spacing`（57〜59行目）
- `wire_clearance`（83行目）
- `inner_l` / `inner_w` / `inner_h` / `body_h`（93〜96・100行目、inner_h のコメント行込み）
- USB プラグ届き assert（`assert(pico_usb_gap > 0 && ...)` とその前のコメント行）
- `test/params_test.scad` 用に残る `body_h` 参照はステップ5で更新

`body_l` / `body_w`（98〜99行目）は inner_l/inner_w 依存だったので、次に置き換える。

```openscad
// プレート外形（旧・箱外形と同じ footprint。壁は無いが名前は互換のため維持）
body_l = ext_left + ext_right + 2*wall;   // 115.8
body_w = ext_down + ext_up  + 2*wall;     // 150.8
```

`pico_y` 導出コメント（107〜110行目付近「同等（Pico の USB 端 → +Y 内壁 = pico_usb_gap）…」）は、壁前提をやめた文面に差し替える。

```openscad
// Pico の配置。pico_usb_gap は「Pico USB 端 → プレート +Y 端（旧内壁線 ext_up）の余白」で、
// USB プラグの抜き差しスペースとして維持する（壁開口は廃止済み・オープン構成）。
pico_usb_gap = 11;
pico_y = ext_up - pico_usb_gap - pico_l/2;    // 83.5
```

- [ ] **Step 3: hardware.scad — usb_cutout() を削除**

`scad/hardware.scad` の `usb_cutout` モジュール全体（「// USB plug opening, centered at origin, cut along Y.」から閉じ括弧まで）を削除する。

- [ ] **Step 4: 不要ファイルの削除と参照更新**

```bash
git rm scad/lid.scad scad/layout_check.scad test/lid_test.scad
```

`scad/smartlock.scad`:
- `use <lid.scad>` の行を削除。
- `else if (part == "lid") lid();` の行を削除。
- `asm_lid` の else-if ブロック（`else if (part == "asm_lid")` から `translate([0, 0, body_h + exp * 5]) lid();` まで）を削除。
- full assembly 内の lid 2行（`color("MediumSeaGreen")` と `translate([0, 0, body_h + exp * 5]) lid();`）を削除。
- `floor_coupon` の直前コメントの「+Y 壁の USB 開口（上端 z≈9.9）のプラグ通りも確認できるようにする」の一文を削除（壁が無いため）。

`scad/tray.scad` の `tray_usb_marker` 直前コメント「// Pico の +Y（USB）端側を指す凹み矢印。USB 端はこちら＝本体 +Y 壁の開口に合わせる。」を次に置き換える。

```openscad
// Pico の +Y（USB）端側を指す凹み矢印。オープン構成でも USB 端の向き合わせ目印として残す。
```

`build.sh` のパートループを次に置き換える。

```bash
for p in body socket tray asm_body asm_socket asm_tray; do
```

`viewer/serve.py` の PARTS を次に置き換える。

```python
PARTS = ["body", "socket", "tray", "assembly", "asm_body", "asm_socket", "asm_tray"]
```

`viewer/index.html`:
- `<option value="lid.stl">蓋 (lid)</option>` の行を削除。
- `assemblyParts` から `{ file: 'asm_lid.stl',    color: 0x3cb371, name: '蓋' },` の行を削除。

- [ ] **Step 5: テストファイル更新**

`test/hardware_test.scad` を次に置き換える。

```openscad
include <../scad/params.scad>
use <../scad/hardware.scad>
// Instantiate every module so undefined ones fail the compile.
difference() {
  cube([60, 40, 30], center = true);
  sg90_cutout();
}
pico_w_mounts();
tray_mount_bosses();
echo("hardware_test ok");
```

`test/params_test.scad` の1つ目の assert を次に置き換える（`body_h` 廃止）。

```openscad
assert(body_l > 0 && body_w > 0, "positive plate dims");
```

- [ ] **Step 6: 参照の取り残しが無いことを確認**

Run: `grep -rn "usb_\|lid\|body_h\|inner_l\|inner_w\|inner_h\|box_corner_r\|wire_clearance\|led_hole\|button_hole\|led_btn" scad/ test/ build.sh viewer/serve.py viewer/index.html`
Expected: ヒットは `tray_usb_marker`（トレイの向きマーカー、意図的に残す）と `pico_usb_gap`（余白パラメータ、意図的に残す）関連のみ。lid / body_h / inner_* / usb_w / led_hole 等の実参照が残っていたら削除漏れなので直す。

- [ ] **Step 7: render / build 確認**

Run: `./build.sh`
Expected: `All parts built to build/`（body socket tray asm_* + gauges すべて Status: NoError）。

Run: `nix develop -c openscad -D 'part="assembly"' -o /tmp/assembly.stl scad/smartlock.scad 2>&1`
Expected: Status: NoError、WARNING/ERROR なし。

- [ ] **Step 8: コミット**

```bash
git add -A
git commit -m "feat(scad): 壁・蓋・USB開口を全廃しオープンベースプレート化

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 3: ペデスタルのボルトオン分離

`mount_plate.scad` を廃止し、プレート（body.scad）とペデスタル単品（pedestal.scad）に分割する。

**Files:**
- Create: `scad/pedestal.scad`
- Create: `test/pedestal_test.scad`
- Modify: `scad/params.scad`（`ped_*` パラメータ＋asserts）
- Modify: `scad/hardware.scad`（`ped_mount_bosses()` 追加）
- Modify: `scad/body.scad`（mount_plate 統合をプレート実装に置換）
- Modify: `scad/smartlock.scad`, `build.sh`, `viewer/serve.py`, `viewer/index.html`
- Delete: `scad/mount_plate.scad`, `test/mount_plate_test.scad`

**Interfaces:**
- Consumes: Task 1 の `m2_boss()` / `m2_sleeve_solid()` / `m2_sleeve_cuts()`。
- Produces:
  - `pedestal()`（pedestal.scad）: ローカル座標（z=0 がフランジ底面）。組立時はワールド `z=wall` に translate。天板上面ローカル = `pedestal_top_z - wall` = 46。
  - `ped_mount_bosses()`（hardware.scad）: `ped_fix_pts` にプレート床から立つボス4本。
  - `pedestal_curb()`（body.scad 内）: 受けカーブ（ローブ切り欠き付き）。
  - params: `ped_flange_t=2.4`, `ped_fix_r=30`, `ped_fix_angles=[45,135,225,315]`, `ped_fix_pts`, `pedestal_fit=0.3`, `ped_curb_wt=2.0`, `ped_curb_h=ped_flange_t`, `ped_lobe_w=10`, `ped_base_d`, `ped_curb_ri`, `ped_curb_ro`。

- [ ] **Step 1: params.scad — ped_* パラメータ追加**

トレイ天面留めブロック（`tray_x0`/`tray_x1` 定義）の直後に、次を追加する。

```openscad
// ペデスタルのボルトオン分離（プレート受けカーブ＋底フランジ、天面 M2 留め）。
// トレイと同じボス/スリーブ/ファンネル構造を流用。フランジ基礎円が受けカーブに落ちて軸センタ
// リング、対角4ローブがカーブ切り欠きと噛んでサーボ反力トルクの回り止め、M2×4 は抜け止め専任。
ped_flange_t   = 2.4;    // 底フランジ厚（トレイ床と同厚＝スリーブ構造を無改造で流用）
ped_fix_r      = 30;     // 固定ボス配置半径。対角4点で -X/-Y プレート端(26/27)とトレイ床(y>=27)を回避
ped_fix_angles = [45, 135, 225, 315];
ped_fix_pts    = [for (a = ped_fix_angles) [ped_fix_r*cos(a), ped_fix_r*sin(a)]];
pedestal_fit   = 0.3;    // フランジ⇔受けカーブの横嵌めすき間（フェーズ2でクーポン実測して確定）
ped_curb_wt    = 2.0;    // 受けカーブ壁厚
ped_curb_h     = ped_flange_t;   // カーブ高（フランジ上面と面一）
ped_lobe_w     = 10;     // フランジローブ幅（スリーブ od 7.8 を内包し、カーブ切り欠きと噛む）
ped_base_d     = 2*(rosette_d/2 + pedestal_wall_t + fit_clearance);  // フランジ基礎円 = 筒外径 50.8
ped_curb_ri    = ped_base_d/2 + pedestal_fit;    // カーブ内半径 25.7
ped_curb_ro    = ped_curb_ri + ped_curb_wt;      // カーブ外半径 27.7
```

- [ ] **Step 2: params.scad — ped 系 asserts 追加**

トレイ固定系 asserts の直後に、次を追加する。

```openscad
// ペデスタル・ボルトオンの配置ガード
assert(ped_fix_r*sin(45) + tray_sleeve_od/2 <= tray_y0, "ペデスタルスリーブがトレイ床に食い込む");
assert(ped_fix_r*cos(45) + tray_sleeve_od/2 <= min(ext_left, ext_down), "ペデスタルスリーブがプレート端を超える");
assert(ped_curb_ro <= min(ext_left, ext_down) + wall - 0.2, "受けカーブがプレート端に寄りすぎ");
assert(ped_fix_r - tray_sleeve_od/2 > rosette_d/2 + fit_clearance, "ペデスタルボスがロゼット開口に食い込む");
assert(ped_lobe_w > tray_sleeve_od, "ローブ幅がスリーブ外径より細い（スリーブがローブから食み出す）");
assert(ped_flange_t < tray_boss_h, "フランジ厚がボス高以上（ボスがスリーブに届かない）");
```

- [ ] **Step 3: hardware.scad — ped_mount_bosses() 追加**

`tray_mount_bosses` モジュールの直後に、次を追加する。

```openscad
// ペデスタルをプレート天面から留めるための本体側ボス。ped_fix_pts（対角4点）に床上面から立てる。
module ped_mount_bosses() {
  for (p = ped_fix_pts)
    translate([p[0], p[1], wall]) m2_boss();
}
```

- [ ] **Step 4: pedestal.scad — 新設**

`scad/pedestal.scad` を次の内容で作成する。

```openscad
include <params.scad>
use <hardware.scad>

// ボルトオン・ペデスタル（ローカル座標: z=0 がフランジ底面。組立時はプレート床上面
// z=wall に載せる）。底フランジ（基礎円＋対角4ローブ）が受けカーブに落ちて軸センタリング、
// ローブがカーブ切り欠きと噛んでサーボ反力トルクの回り止め。固定はローブ上のスリーブ4個へ
// 天面から M2 セルフタップ（トレイと同構造・ファンネル穴）。クランプはネジ張力×フランジ底の
// プレート密着で効く。筒＋サーボ天板は旧 mount_plate と同形状で、天板上面はワールド
// pedestal_top_z(48.4) を維持する（ローカルでは pedestal_top_z - wall = 46）。
module pedestal() {
  c = fit_clearance;
  pr  = rosette_d/2 + pedestal_wall_t + c;   // 筒外半径 25.4（旧 mount_plate と同じ）
  top = pedestal_top_z - wall;               // 天板上面（ローカル 46）
  difference() {
    union() {
      // 底フランジ: 基礎円＋対角4ローブ（スリーブ受け兼回り止めタブ）。中央穴は difference 側
      linear_extrude(height = ped_flange_t)
        union() {
          circle(r = pr);
          for (p = ped_fix_pts)
            hull() {
              translate([p[0]/2, p[1]/2]) circle(d = ped_lobe_w);
              translate([p[0],   p[1]])   circle(d = ped_lobe_w);
            }
        }
      // 筒壁（フランジ内から天板まで。旧 mount_plate のリングと同径）
      linear_extrude(height = top)
        difference() {
          circle(r = pr);
          circle(r = pr - pedestal_wall_t);
        }
      // サーボ天板（旧 mount_plate と同一: 厚 servo_plate_t、シャフト穴＋耳ネジ下穴。
      // 下穴はサーボ本体中心（servo_shaft_offset ぶん偏心）基準の非対称配置）
      translate([0, 0, top - servo_plate_t])
        linear_extrude(height = servo_plate_t)
          difference() {
            circle(r = pr);
            circle(d = servo_shaft_d + 2*c);
            for (sx = [-1, 1])
              translate([servo_shaft_offset + sx * servo_screw_span/2, 0])
                circle(d = servo_screw_pilot);
          }
      // 固定スリーブ（トレイと同じ共有モジュール）
      for (p = ped_fix_pts)
        translate([p[0], p[1], 0]) m2_sleeve_solid();
    }
    // サーボポケット（天板にタブが載る。ローカル z 基準）
    translate([0, 0, top + servo_body_h/2])
      sg90_cutout();
    // 中央ロゼット通し（フランジを貫通）
    translate([0, 0, -0.1])
      cylinder(d = rosette_d + c, h = ped_flange_t + 0.2);
    // スリーブの内側カット（ボア/ファンネル/throat/頭ザグリ）
    for (p = ped_fix_pts)
      translate([p[0], p[1], 0]) m2_sleeve_cuts();
  }
}

// standalone render target (ignored by `use <pedestal.scad>`)
pedestal();
```

- [ ] **Step 5: body.scad — mount_plate 統合をプレート実装へ置換**

`scad/body.scad` の中身全体を次に置き換える（`use <mount_plate.scad>` を外し、`use <pedestal.scad>` は不要 — body はペデスタルを含まない）。

```openscad
include <params.scad>
use <hardware.scad>

// Origin = thumb-turn / servo axis (center of the door rosette).
// オープンベースプレート: ドアに両面テープで貼る1枚板。外周壁・蓋・USB 開口なし。
// ペデスタル（pedestal.scad）とトレイ（tray.scad）は天面から M2 でボルトオンする。
// 剛性は使用中はドアが担い、手持ち時のリブは Task 4 で追加。
module body() {
  c = fit_clearance;
  difference() {
    union() {
      // 床プレート（角R2。旧・箱の床と同じ footprint）
      translate([center_x, center_y, 0])
        linear_extrude(height = wall)
          plate_outline_2d();
      // ペデスタル受けカーブ（ローブ通過の切り欠き＝回り止め）
      pedestal_curb();
      // 固定ボス（トレイ4＋ペデスタル4、天面 M2 留め）
      tray_mount_bosses();
      ped_mount_bosses();
    }
    // 中央ロゼット開口（ドア側のサムターン座金を通す）
    translate([0, 0, -0.1])
      cylinder(d = rosette_d + c, h = wall + 0.2);
  }
}

// プレート外形 2D（原点基準・中心合わせは呼び出し側の translate で行う）
module plate_outline_2d() {
  offset(r = 2) offset(r = -2)
    square([body_l, body_w], center = true);
}

// 受けカーブ: フランジ基礎円（φ ped_base_d）を囲む土手リング。ped_fix_angles の各角度に
// ローブ通過の切り欠き（幅 = ローブ幅 + 両側 pedestal_fit）。切り欠き側面がローブと噛んで
// サーボ反力トルクの回り止めになる。プレートは薄く掘れないので「ポケット」ではなく土手で受ける。
module pedestal_curb() {
  translate([0, 0, wall])
    linear_extrude(height = ped_curb_h)
      difference() {
        circle(r = ped_curb_ro);
        circle(r = ped_curb_ri);
        for (a = ped_fix_angles)
          rotate([0, 0, a])
            translate([(ped_curb_ri + ped_curb_ro)/2, 0])
              square([ped_curb_wt*2 + 2, ped_lobe_w + 2*pedestal_fit], center = true);
      }
}
```

```bash
git rm scad/mount_plate.scad test/mount_plate_test.scad
```

- [ ] **Step 6: test/pedestal_test.scad — 新設**

```openscad
include <../scad/params.scad>
use <../scad/pedestal.scad>
pedestal();
echo("pedestal_test ok");
```

- [ ] **Step 7: smartlock.scad — pedestal パート追加・mount_coupon 差し替え・assembly 更新**

`use <body.scad>` の下に `use <pedestal.scad>` を追加する。

`else if (part == "tray") tray();` の直後に追加:

```openscad
else if (part == "pedestal") pedestal();
```

`mount_coupon` の else-if ブロック全体を次に置き換える（body ではなく pedestal 単品から切り出す。ローカル座標なので translate 量が変わる）。

```openscad
// ペデスタル天板のみ切り出した薄型クーポン（サーボ耳の位置・ネジ効き確認用）
else if (part == "mount_coupon")
  translate([0, 0, -(pedestal_top_z - wall - servo_plate_t)]) // 天板下面をベッドに接地
    intersection() {
      pedestal();
      translate([0, 0, pedestal_top_z - wall - servo_plate_t])
        // 半径をペデスタル外周までに絞り、フランジ/スリーブを巻き込まない
        cylinder(r = rosette_d/2 + pedestal_wall_t + fit_clearance + 0.1,
                 h = servo_plate_t + 0.5);
    }
```

`asm_tray` ブロックの直後に追加:

```openscad
else if (part == "asm_pedestal")
  color("Khaki")
    translate([0, 0, wall + exp * 8]) pedestal();
```

full assembly（最後の else ブロック）の `color("Plum") translate([0, 0, wall + exp * 10]) tray();` の直前に追加:

```openscad
  color("Khaki")
    translate([0, 0, wall + exp * 8]) pedestal();
```

- [ ] **Step 8: build.sh / viewer にペデスタル追加**

`build.sh` のパートループを次に置き換える。

```bash
for p in body pedestal socket tray asm_body asm_pedestal asm_socket asm_tray; do
```

`viewer/serve.py` の PARTS を次に置き換える。

```python
PARTS = ["body", "pedestal", "socket", "tray", "assembly", "asm_body", "asm_pedestal", "asm_socket", "asm_tray"]
```

`viewer/index.html`:
- `<option value="body.stl">本体 (body)</option>` の直後に `<option value="pedestal.stl">サーボ台座 (pedestal)</option>` を追加。
- `assemblyParts` の `asm_body` 行の直後に `{ file: 'asm_pedestal.stl', color: 0xf0e68c, name: 'サーボ台座' },` を追加。

- [ ] **Step 9: render / build 確認**

Run: `./test/render.sh scad/pedestal.scad`
Expected: `OK: /tmp/pedestal.stl`、WARNING/ERROR/assert なし。

Run: `./build.sh`
Expected: `All parts built to build/`（body pedestal socket tray asm_* すべて NoError）。

Run: `nix develop -c openscad -D 'part="mount_coupon"' -o /tmp/mount_coupon.stl scad/smartlock.scad 2>&1`
Expected: Status: NoError（サーボ耳クーポンがペデスタル基準で切り出せる）。

- [ ] **Step 10: コミット**

```bash
git add -A
git commit -m "feat(scad): ペデスタルをボルトオン分離（受けカーブ＋フランジローブ＋天面M2×4）

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 4: プレートの上面リブ（手持ち剛性・反り対策）

**Files:**
- Modify: `scad/params.scad`（リブパラメータ＋asserts）
- Modify: `scad/body.scad`（`plate_ribs()` 追加）

**Interfaces:**
- Consumes: `plate_outline_2d()`, `ped_curb_ro`, `ped_fix_r`, `tray_sleeve_od`, `tray_y0`。
- Produces: `plate_ribs()`（body 内部モジュール）。

- [ ] **Step 1: params.scad — リブパラメータ追加**

ped_* ブロックの直後に追加:

```openscad
// プレート上面リブ（手持ち時の剛性・印刷反り対策。ドア面はフラット維持）。
// 横桟はトレイ床(y>=tray_y0=27)とペデスタルスリーブ帯(対角 y≈17.3〜25.1)を避けた位置に置く。
plate_rib_h  = 4;            // リブ高（床上面から）
plate_rib_w  = 2;            // リブ幅
plate_rib_ys = [-14, 14];    // 横桟の y（受けカーブとの交差は差し引きで自動処理）
```

- [ ] **Step 2: params.scad — リブ干渉 asserts 追加**

ped 系 asserts の直後に追加:

```openscad
assert(max(plate_rib_ys) + plate_rib_w/2 < tray_y0, "横桟がトレイ床に食い込む");
assert(max(plate_rib_ys) + plate_rib_w/2 <= ped_fix_r*sin(45) - tray_sleeve_od/2, "横桟がペデスタルスリーブに食い込む");
```

- [ ] **Step 3: body.scad — plate_ribs() を追加**

`body()` の union 内、`pedestal_curb();` の直前に `plate_ribs();` を追加し、`pedestal_curb` モジュールの直後に次を追加する。

```openscad
// 上面リブ: 外周一周＋横桟。受けカーブ・スリーブ・ロゼット開口の周りは半径 ped_curb_ro+1 で
// 丸ごと逃がす（開口の上をリブが橋渡しして印刷ブリッジになるのも防ぐ）。トレイ床の下（y>=tray_y0）
// には横桟を置かない（plate_rib_ys で保証、assert 済み）。
module plate_ribs() {
  translate([0, 0, wall])
    linear_extrude(height = plate_rib_h)
      difference() {
        union() {
          // 外周リブ（プレート輪郭の内側 plate_rib_w 幅）
          translate([center_x, center_y])
            difference() {
              plate_outline_2d();
              offset(delta = -plate_rib_w) plate_outline_2d();
            }
          // 横桟（全幅。外周リブと融合する）
          for (y = plate_rib_ys)
            translate([center_x, y])
              square([body_l, plate_rib_w], center = true);
        }
        // 受けカーブ・スリーブ・中央開口まわりの逃げ
        circle(r = ped_curb_ro + 1);
      }
}
```

注意: `plate_outline_2d()` は原点基準 2D（中心合わせは translate 側）なので、外周リブの difference は `translate([center_x, center_y])` の下で行う（上のコード通り）。

- [ ] **Step 4: render / build 確認**

Run: `./build.sh`
Expected: `All parts built to build/`、全パート NoError。body.stl にリブが付き、他パートは不変。

- [ ] **Step 5: コミット**

```bash
git add scad/params.scad scad/body.scad
git commit -m "feat(scad): プレート上面リブ（外周＋横桟、手持ち剛性・反り対策）

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 5: 嵌合クーポン ped_mount_coupon ＋ README 更新

**Files:**
- Modify: `scad/smartlock.scad`（`ped_mount_coupon` パート追加）
- Modify: `README.md`（部品構成・ビルド出力の記述更新）

**Interfaces:**
- Consumes: `body()`, `pedestal()`, `ped_fix_pts`, `tray_boss_h`, `tray_cap_t`, `wall`。
- Produces: `part == "ped_mount_coupon"`（プレート側パッチ＋ペデスタル側パッチを X 方向に並べて出力。両方とも底面 z=0 がベッド接地）。

- [ ] **Step 1: smartlock.scad — クーポン part 追加**

`tray_mount_coupon` ブロックの直後に追加する。

```openscad
// ペデスタル固定の嵌合クーポン（フランジ⇔受けカーブの横嵌め pedestal_fit・ローブ⇔切り欠きの
// 噛み・M2 の効き・面一沈み確認用）。45° の固定点まわりを本物の body/pedestal から切り出す。
// 両方とも底面 z=0 がベッド接地。ペデスタル側は印刷用に +X へ退避。
else if (part == "ped_mount_coupon") {
  cp = ped_fix_pts[0];   // 45° の固定点 (≈21.2, 21.2)
  hw = 14;               // 切り出し半幅（カーブ切り欠き・ローブ・ボス・カーブ本体を含む）
  // プレート側（床パッチ＋ボス1本＋カーブの切り欠き部分）
  intersection() {
    body();
    translate([cp[0], cp[1], (wall + tray_boss_h + 2)/2 - 0.1])
      cube([2*hw, 2*hw, wall + tray_boss_h + 2], center = true);
  }
  // ペデスタル側（フランジローブ＋スリーブ1個＋筒壁の一部）
  translate([2*hw + 8, 0, 0])
    intersection() {
      pedestal();
      translate([cp[0], cp[1], (tray_boss_h + tray_cap_t + 2)/2 - 0.1])
        cube([2*hw, 2*hw, tray_boss_h + tray_cap_t + 2], center = true);
    }
}
```

- [ ] **Step 2: クーポン render 確認**

Run: `nix develop -c openscad -D 'part="ped_mount_coupon"' -o /tmp/ped_mount_coupon.stl scad/smartlock.scad 2>&1`
Expected: Status: NoError、WARNING/ERROR なし。2ピースが離れて出力される。

- [ ] **Step 3: README.md 更新**

筐体テーブル行（「| 筐体 | `scad/` | ドアに後付けする本体・蓋・サムターン受け | …」）の説明セルを次に置き換える。

```
ドアに貼るベースプレート＋ボルトオンのサーボ台座・電子部品トレイ・サムターン受け（壁・蓋なしのオープン構成）
```

ビルド出力の説明行（「build/ に body.stl / lid.stl / socket.stl を出力する。…」）を次に置き換える。

```
build/ に body.stl / pedestal.stl / socket.stl / tray.stl（と asm_* プレビュー）を出力する。dev シェル外でも自動で nix develop 経由で実行される。
```

- [ ] **Step 4: 最終確認（全体）**

Run: `./build.sh`
Expected: `All parts built to build/`。

Run: `grep -rn "mount_plate\|layout_check" scad/ test/ build.sh viewer/`
Expected: ヒットなし（削除済みシンボルの参照ゼロ）。

- [ ] **Step 5: コミット**

```bash
git add scad/smartlock.scad README.md
git commit -m "feat(scad): ペデスタル嵌合クーポン追加＋README をオープン構成に更新

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## フェーズ2（印刷して実測 → 反映。コード外の物理作業）

1. `ped_mount_coupon` を印刷し、以下を実測・確認する。
   - フランジ⇔受けカーブの横嵌め `pedestal_fit`（スルッと入りガタつかないか）。
   - ローブ⇔切り欠きの噛み（回転ガタ。サーボ反力を受けるので渋め推奨）。
   - フランジがカーブに面一で沈み、フランジ底がプレート床に密着するか。
   - M2 セルフタップの効き（ボスはトレイと同仕様なので流用実績あり、確認のみ）。
2. 実測から `pedestal_fit`（必要なら `ped_lobe_w` / `ped_curb_wt`）を確定し、`params.scad` を更新。
3. `./build.sh` 再実行 → `body` / `pedestal` / `tray` を印刷して通し組み（4ボス同時嵌合・トレイ密着・ペデスタル密着・ソケット/ホーン嵌合）を確認。
4. LED/押しボタンは lid の穴が無くなったため、ブレッドボード上の実装がそのまま見える（実機検証済みの配置。パネルマウントは廃止）。

## Self-Review（記入済み）

- **Spec coverage:** プレート化（床/リブ/ポケット→カーブ/ボス）=T2〜T4。ペデスタル分離（フランジ/タブ→ローブ/スリーブ/天板）=T3。壁・蓋・USB 全廃=T2。クーポン=T5。`pedestal_top_z` 不変=T3 Step4（ローカル top=46）＋既存 asserts 温存。ドア面無傷=ボス袋下穴（既存）＋ロゼット開口のみ。spec の「3スリーブ」「ポケット」「ノッチ」は冒頭「spec からの設計変更」に根拠付きで明記（4点・カーブ・ローブ兼用）。
- **Placeholder scan:** TBD/TODO なし。`pedestal_fit=0.3` は設計初期値で render が通り、フェーズ2実測で確定（意図的・spec 通り）。
- **Type consistency:** `m2_boss`/`m2_sleeve_solid`/`m2_sleeve_cuts`（T1定義→T3使用）、`ped_fix_pts`/`ped_fix_angles`/`ped_curb_ri`/`ped_curb_ro`/`ped_lobe_w`（T3 params→body/pedestal/T5 で一致）、`plate_outline_2d`（T3定義→T4使用、原点基準の規約を両所で明記）、`pedestal()` ローカル z=0 規約（T3 Step4/Step7/T5 で一致）。削除シンボル（lid/mount_plate/usb_cutout/body_h/inner_*）の参照除去は T2 Step6 / T5 Step4 の grep で機械確認。
