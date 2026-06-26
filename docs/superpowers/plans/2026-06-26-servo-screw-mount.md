# サーボ（SG90）ネジ固定 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** SG90 サーボをポケット摩擦保持から、床立ちボス＋M2 タッピングねじによる固定へ変更する。

**Architecture:** `params.scad` にネジ・ボスの寸法パラメータと整合 assert を追加し、`hardware.scad` に2本の床ボス（下穴付き）を生成する `servo_mounts()` を新設、`sg90_cutout()` のタブ逃げを上端から床側（実物のシャフト端）へ移す。`body.scad` でサーボをボス高さ分持ち上げ、ボスを実体側に配置する。検証は OpenSCAD の `render.sh`（WARNING/ERROR・非ゼロ終了で fail、`assert` 違反もエラー）で行う。

**Tech Stack:** OpenSCAD（宣言的 CAD）、`test/render.sh`（Nix dev シェル経由で `openscad` 実行）。

## Global Constraints

- `build/` と `*.stl` は派生物。コミットしない（.gitignore 済み）。
- `openscad` は Nix dev シェル内のみ。`./test/render.sh <scad>` は自分で再突入するのでそのまま実行可。
- 角度→パルス等のサーボ制御定数（`servo_math.rs` / `servo.rs`）は本タスクの対象外。筐体（`scad/`）のみ変更する。
- 既存の `render.sh` 規約: `WARNING` / `ERROR` を1つでも出すと fail。新規 assert はこの仕組みで検査される。

---

### Task 1: ネジ・ボス寸法パラメータと整合 assert

**Files:**
- Modify: `scad/params.scad`（servo ブロック L10-17 付近に追加、未使用の `servo_screw_d` を置換。assert は L75-86 付近の末尾に追加）

**Interfaces:**
- Consumes: 既存 `servo_tab_h`, `servo_tab_l`, `ext_left`
- Produces: グローバル変数 `servo_screw_span`(=27.6), `servo_screw_pilot`(=1.8), `servo_boss_d`(=4.5), `servo_boss_h`(=4.0)

- [ ] **Step 1: 未使用パラメータの参照がないことを確認**

Run:
```bash
grep -rn "servo_screw_d" scad/
```
Expected: `scad/params.scad` の定義行のみがヒット（他から参照されていない＝安全に置換可）。

- [ ] **Step 2: `params.scad` のサーボブロックを更新**

`scad/params.scad` の以下の行（L17）:
```
servo_screw_d = 2.0;
```
を、次の4行へ置き換える:
```
servo_screw_span  = 27.6;  // 耳のネジ穴 中心間（データシート公称・要実測補正）
servo_screw_pilot = 1.8;   // M2 セルフタッピング下穴径
servo_boss_d      = 4.5;   // 耳ボス外径（Pico ボスと同径。ポケット/タブ干渉を回避）
servo_boss_h      = 4.0;   // 床からの耳ボス高さ（M2 ねじ山確保＋出力ホーン逃げ）
```

- [ ] **Step 3: 整合 assert を追加**

`scad/params.scad` 末尾の assert 群（`assert(knob_engage < knob_h, ...)` の後）に追記:
```
// --- Servo screw-mount checks ---
assert(servo_screw_pilot < servo_boss_d, "pilot hole smaller than boss");
assert(servo_boss_h >= servo_tab_h, "boss tall enough to seat the tab");
assert(servo_screw_span/2 + servo_boss_d/2 <= ext_left, "screw boss within interior (-X side)");
```

- [ ] **Step 4: params が読み込まれる既存モデルが通ることを確認（assert 検査）**

Run:
```bash
./test/render.sh scad/body.scad
```
Expected: 末尾に `OK: /tmp/body.stl`。assert 違反・WARNING・ERROR が無いこと。
（数値確認: `servo_screw_span/2 + servo_boss_d/2 = 13.8 + 2.25 = 16.05 <= ext_left(20)`、`servo_boss_h(4) >= servo_tab_h(2.5)`、`servo_screw_pilot(1.8) < servo_boss_d(4.5)` ＝全て真。）

- [ ] **Step 5: コミット**

```bash
git add scad/params.scad
git commit -m "feat(scad): サーボネジ固定の寸法パラメータと整合 assert を追加"
```

---

### Task 2: `servo_mounts()` モジュールとタブ逃げ位置の修正

**Files:**
- Modify: `scad/hardware.scad`（`sg90_cutout()` のタブ逃げ translate、末尾に `servo_mounts()` 追加）
- Create: `test/servo_mount_test.scad`（新モジュールの red→green 用ハーネス）

**Interfaces:**
- Consumes: Task 1 のグローバル変数（`servo_screw_span`, `servo_screw_pilot`, `servo_boss_d`, `servo_boss_h`）、既存 `servo_body_h`, `servo_tab_h`, `servo_tab_l`, `servo_body_w`, `fit_clearance`
- Produces: モジュール `servo_mounts()` — 原点基準で `(±servo_screw_span/2, 0, 0)` に床から立つ高さ `servo_boss_h`・外径 `servo_boss_d` のボス2本、各々中心に `servo_screw_pilot` 径の貫通下穴。配置側（呼び出し元）が Z を与える前提でローカル Z=0 起点。

- [ ] **Step 1: 失敗するテストハーネスを作成**

Create `test/servo_mount_test.scad`:
```
// Render harness for servo_mounts(): proves the module exists and renders
// to a manifold STL with two pilot-drilled bosses. params asserts also run.
include <../scad/params.scad>
use <../scad/hardware.scad>

servo_mounts();
```

- [ ] **Step 2: テストを実行して失敗を確認**

Run:
```bash
./test/render.sh test/servo_mount_test.scad
```
Expected: FAIL。`servo_mounts()` 未定義により WARNING/ERROR（`Ignoring unknown module 'servo_mounts'` 等）が出て `FAIL: warnings/errors present`。

- [ ] **Step 3: `servo_mounts()` を実装**

`scad/hardware.scad` の末尾（`mosfet_space()` の後）に追加:
```
// Two floor-standing bosses with M2 self-tapping pilot holes, under the SG90
// mounting tabs. Centered on the shaft axis; caller supplies the Z origin
// (boss base at local Z=0, rising +Z to servo_boss_h).
module servo_mounts() {
  for (sx = [-1, 1])
    translate([sx * servo_screw_span/2, 0, 0])
      difference() {
        cylinder(d = servo_boss_d, h = servo_boss_h);
        translate([0, 0, -0.1])
          cylinder(d = servo_screw_pilot, h = servo_boss_h + 0.2);
      }
}
```

- [ ] **Step 4: テストを実行して成功を確認**

Run:
```bash
./test/render.sh test/servo_mount_test.scad
```
Expected: `OK: /tmp/servo_mount_test.stl`。WARNING/ERROR なし。

- [ ] **Step 5: `sg90_cutout()` のタブ逃げを床側（-Z）へ移動**

`scad/hardware.scad` の `sg90_cutout()` 内、タブ逃げの translate（現状）:
```
    // mounting tabs (wider in length)
    translate([0, 0, servo_body_h/2 - servo_tab_h/2])
      cube([servo_tab_l + 2*c, servo_body_w + 2*c, servo_tab_h + 2*c], center = true);
```
を、Z を反転して床側へ:
```
    // mounting tabs (wider in length) — at the shaft/floor end, matching the
    // real SG90 where the tabs sit on the output-shaft side.
    translate([0, 0, -(servo_body_h/2 - servo_tab_h/2)])
      cube([servo_tab_l + 2*c, servo_body_w + 2*c, servo_tab_h + 2*c], center = true);
```

- [ ] **Step 6: タブ移動後もテストハーネスとアセンブリが通ることを確認**

Run:
```bash
./test/render.sh test/servo_mount_test.scad && ./test/render.sh scad/smartlock.scad
```
Expected: 両方 `OK: ...`。WARNING/ERROR なし。
（注: `scad/body.scad` は単体だと top-level 呼び出しが無く空になりエラーするため、アセンブリ `smartlock.scad` でレンダー検証する。この時点では body はまだ `servo_mounts()` を呼ばず、サーボ持ち上げも未実施。タブ逃げ位置変更が単体でレンダー破綻しないことの確認。）

- [ ] **Step 7: コミット**

```bash
git add scad/hardware.scad test/servo_mount_test.scad
git commit -m "feat(scad): servo_mounts() ボス追加とタブ逃げを床側へ移動"
```

---

### Task 3: `body.scad` へ統合（サーボ持ち上げ＋ボス配置）

**Files:**
- Modify: `scad/body.scad`（サーボ配置 translate L48、union 内にボス追加 L43-44 付近）

**Interfaces:**
- Consumes: Task 2 の `servo_mounts()`、Task 1 の `servo_boss_h`、既存 `wall`, `servo_body_h`, `servo_x/servo_y`(=0,0)
- Produces: なし（最終アセンブリ）

- [ ] **Step 1: サーボ配置を `servo_boss_h` 分持ち上げる**

`scad/body.scad` の servo pocket 配置（現状 L47-49）:
```
    // servo pocket at the axis (shaft down through the bottom)
    translate([servo_x, servo_y, wall + servo_body_h/2])
      sg90_cutout();
```
を、ボス高さ分持ち上げる:
```
    // servo pocket at the axis (shaft down through the bottom); lifted by
    // servo_boss_h so the mounting tabs rest on the screw bosses.
    translate([servo_x, servo_y, wall + servo_boss_h + servo_body_h/2])
      sg90_cutout();
```

- [ ] **Step 2: ボスを実体（union）側に配置**

`scad/body.scad` の union 内、Pico スタンドオフの後（L43-44 付近）に追加:
```
      // Servo screw bosses, rising from the floor at the shaft axis
      translate([servo_x, servo_y, wall])
        servo_mounts();
```
（`servo_x` / `servo_y` は同モジュール内 L10-11 で `0` 定義済み。`use <hardware.scad>` は L2 で取得済みのため追加 import 不要。）

- [ ] **Step 3: アセンブリ全体をレンダーして成功を確認**

Run:
```bash
./test/render.sh scad/smartlock.scad
```
Expected: `OK: /tmp/smartlock.stl`、`Simple: yes`（manifold）、WARNING/ERROR なし。
（注: `scad/body.scad` は単体だと top-level 呼び出しが無く空になりエラーするため、body を実体化する `smartlock.scad` で検証する。）

- [ ] **Step 4: body 単体をハーネス経由でレンダーして成功を確認**

Run:
```bash
./test/render.sh scad/smartlock.scad /tmp/smartlock_servo.stl
```
Expected: `OK: /tmp/smartlock_servo.stl`、`Simple: yes`、WARNING/ERROR なし。

- [ ] **Step 5: 目視確認（STL を生成し所見を記録）**

Run:
```bash
./test/render.sh scad/smartlock.scad /tmp/smartlock_servo.stl
```
（`part="body"` で本体のみ見たい場合は `nix develop -c openscad -D 'part="body"' -o /tmp/body_servo.stl scad/smartlock.scad`）
確認ポイント（`viewer/` か任意の STL ビューアで開く。所見をコミットメッセージか PR に記録）:
- サーボポケットの床側に耳ボスが2本立っている
- 各ボスに下穴が貫通している
- ボスが側壁・MOSFET 域・Pico スタンドオフと干渉していない

- [ ] **Step 6: コミット**

```bash
git add scad/body.scad
git commit -m "feat(scad): サーボをボス上に持ち上げ servo_mounts を本体へ配置"
```

---

## Self-Review

- **Spec coverage:**
  - params 追加・`servo_screw_d` 置換 → Task 1 ✓
  - assert 群 → Task 1 Step 3 ✓
  - `sg90_cutout()` タブ逃げ移動 → Task 2 Step 5 ✓
  - `servo_mounts()` 新設 → Task 2 Step 3 ✓
  - `body.scad` サーボ持ち上げ＋ボス配置 → Task 3 ✓
  - 干渉チェック → Task 3 Step 5（目視）＋ Task 1 の interior assert ✓
  - テスト（render.sh で body/smartlock）→ Task 3 Step 3-4 ✓
  - スコープ外（socket 再キャリブ、実測値確定、パーツ表追記）→ 本プランでは扱わない（spec と一致）✓
- **Placeholder scan:** プレースホルダなし。全ステップに実コード／実コマンド／期待出力あり。
- **Type/名前整合:** `servo_mounts`, `servo_screw_span`, `servo_screw_pilot`, `servo_boss_d`, `servo_boss_h` は全タスクで綴り一致。`servo_x`/`servo_y` は `body.scad` 内定義を参照。
