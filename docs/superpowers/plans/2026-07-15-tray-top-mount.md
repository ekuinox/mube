# トレイ天面留め 実装プラン

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 電子部品トレイの固定を「本体裏（ドア面）からのネジ留め」から「天面（内側）からのネジ留め」に変え、ドアに本体を貼ったままトレイを着脱できるようにする。

**Architecture:** ボディ床から M2 セルフタップ用のボスを立て、トレイ側はそのボスに被さる「スリーブ＋上端キャップ耳」にする。ボスがスリーブへ下から刺さって XY 位置決めを兼ね、天面から M2 をキャップ耳に通してボス上面へ締めるとトレイが固定される。ドア面（`z=0`）には穴を出さない。

**Tech Stack:** OpenSCAD（nix devShell 内）。検証は `./test/render.sh` / `./build.sh` の Status: NoError と `params.scad` の assert。

## Global Constraints

- `openscad` は nix devShell 内のみ。素の呼び出しは `nix develop -c openscad ...`、`.sh` はそのまま実行可（自己再突入する）。
- ソースコメントは日本語で、説明を十分に足す。
- ドア面（`z=0`）に固定用の穴・ザグリを出さない（袋下穴はボス内で止め、床を貫通させない）。
- ボス肉厚基準は Pico に倣い `boss_d > pilot + 1.6`。
- `build/` と `*.stl` は非コミット（.gitignore 済み）。
- 効き代（セルフタップ噛み）は既存トレイと同じ `tray_screw_grip = 5`。
- 実測で確定するのは横嵌めすき間 `boss_fit` のみ（フェーズ2）。それ以外は設計値で確定。

## File Structure

- `scad/params.scad` — 新パラメータ（`tray_boss_d` / `tray_boss_h` / `boss_fit` / `tray_sleeve_wt` / `tray_cap_t` と派生 `tray_sleeve_id` / `tray_sleeve_od`）。固定点位置とトレイ床 X 範囲をスリーブ外径基準に更新。旧 `tray_fix_d` / `tray_fix_h` を削除。assert を更新。
- `scad/hardware.scad` — `tray_mount_cuts()`（裏ザグリ＋床貫通）を `tray_mount_bosses()`（床から立つ加算ボス）に置換。
- `scad/body.scad` — `difference()` の cut から `tray_mount_cuts()` を除去し、union へ `tray_mount_bosses()` を追加。
- `scad/tray.scad` — 固定ポスト＋袋下穴を、スリーブ solid（union）＋ボス逃げボア/ネジ通し/頭ザグリ（difference cut）に置換。
- `scad/tray_pilot_gauge.scad` — 母材がトレイ→ボディへ移るのに合わせ、`tray_fix_d/h` を `tray_boss_d/h` に差し替え＋コメント整合（下穴径・効き代は据え置き）。
- `scad/smartlock.scad` — 既存 `tray_coupon` の旧シンボル参照を更新。新パート `tray_mount_coupon`（本体ボス1本＋トレイスリーブ1個の嵌合クーポン）を追加。

---

### Task 1: コア形状の置換（裏留め → 天面留め）

params・hardware・body・tray・gauge・smartlock(tray_coupon) は互いに参照し合うため、途中で render が壊れないよう一括で変更する。

**Files:**
- Modify: `scad/params.scad`
- Modify: `scad/hardware.scad:43-55`
- Modify: `scad/body.scad:39-41`（cut 除去）, `scad/body.scad:28`付近（union へ追加）
- Modify: `scad/tray.scad:38-47`
- Modify: `scad/tray_pilot_gauge.scad:1-11,38-41`
- Modify: `scad/smartlock.scad:22-28`

**Interfaces:**
- Produces:
  - `tray_mount_bosses()`（hardware.scad）: 引数なし。`tray_fix_pts` の各点にボディ床上面（`z=wall`）から `tray_boss_h` の円柱ボスを立て、上面から `tray_screw_pilot` の袋下穴を `tray_screw_grip` 深さで彫る。加算形状（union で使う）。
  - `tray_fix_sleeve` 相当のスリーブ形状は tray.scad 内にインライン展開（別モジュール化しない）。
  - 新パラメータ: `tray_boss_d=5`, `tray_boss_h=tray_screw_grip+1`, `boss_fit=0.4`, `tray_sleeve_wt=1.0`, `tray_cap_t=2.5`, `tray_sleeve_id=tray_boss_d+2*boss_fit`, `tray_sleeve_od=tray_sleeve_id+2*tray_sleeve_wt`。
  - 更新パラメータ: `tray_fix_x_right = pocket_outer_right + tray_fix_gap + tray_sleeve_od/2`、`tray_x0/x1` はスリーブ外径基準。
  - 削除パラメータ: `tray_fix_d`, `tray_fix_h`。

- [ ] **Step 1: params.scad — 新パラメータ追加＋固定点/床範囲更新＋旧ポスト径削除**

`scad/params.scad` の該当ブロック（157〜172 行の `tray_fix_d`〜`tray_x1` 周辺）を、次に置き換える。

```openscad
// トレイ天面留め：本体側ボス＋トレイ側スリーブ（旧・裏留めポストを置換）。
// ボディ床からボスを立て、トレイのスリーブが上から被さる。天面から M2 セルフタップで
// キャップ耳をボス上面へ締めてトレイを固定する。ドア面(z=0)は袋下穴で貫通させない。
tray_boss_d    = 5;                       // 本体ボス外径（Pico の pico_boss_d に倣い肉厚確保）
tray_boss_h    = tray_screw_grip + 1;     // ボス高 = 効き代5 + 底残し1 = 6（床下=ドア面を貫通しない）
boss_fit       = 0.4;                     // ボス⇔スリーブ横嵌めすき間（フェーズ2でクーポン実測して確定）
tray_sleeve_wt = 1.0;                      // スリーブ壁厚
tray_cap_t     = 2.5;                      // スリーブ上端キャップ厚（頭ザグリ tray_head_h=1.6 + 座残し 0.9）
tray_sleeve_id = tray_boss_d + 2*boss_fit;             // ボア径（ボス逃げ）= 5.8
tray_sleeve_od = tray_sleeve_id + 2*tray_sleeve_wt;    // スリーブ外径 = 7.8

tray_fix_gap     = 1;      // ポケット外壁 → 右スリーブのすき間
tray_fix_x_left  = -20;    // 左スリーブ列（Pico 左 -10.5 と壁 -27 の間）
tray_fix_x_right = pocket_outer_right + tray_fix_gap + tray_sleeve_od/2;  // 81.4
tray_fix_y_lo    = 40;
tray_fix_y_hi    = 100;
tray_fix_pts = [
  [tray_fix_x_left,  tray_fix_y_lo], [tray_fix_x_left,  tray_fix_y_hi],
  [tray_fix_x_right, tray_fix_y_lo], [tray_fix_x_right, tray_fix_y_hi],
];

// トレイ床 X 範囲（スリーブ外径基準）。右は +X 壁が近いのでスリーブ外周に flush（余白0）。
tray_x0 = tray_fix_x_left  - tray_sleeve_od/2 - 1;   // -24.9
tray_x1 = tray_fix_x_right + tray_sleeve_od/2;        // 85.3
```

- [ ] **Step 2: params.scad — assert をスリーブ外径基準に更新**

`scad/params.scad` の 220〜223 行の固定ポスト系 assert を、次に置き換える（`tray_fix_d/2` → `tray_sleeve_od/2`、ボス肉厚/効き代 assert を追加）。

```openscad
assert(tray_boss_d > tray_screw_pilot + 1.6, "ボス肉厚が下穴に対して薄すぎる");
assert(tray_screw_grip < tray_boss_h, "ネジ下穴 grip がボス高を超える（床貫通の恐れ）");
assert(tray_cap_t > tray_head_h, "キャップ厚が頭ザグリ深さ以下（頭が座らない）");
assert(tray_fix_x_right - tray_sleeve_od/2 >= pocket_outer_right, "右スリーブが BB ポケットに食い込む");
assert(tray_fix_x_right + tray_sleeve_od/2 <= ext_right, "右スリーブが +X 壁を超える");
assert(tray_fix_x_left  + tray_sleeve_od/2 <= pico_x - pico_w/2, "左スリーブが Pico に食い込む");
assert(tray_fix_x_left  - tray_sleeve_od/2 >= -ext_left, "左スリーブが -X 壁を超える");
```

- [ ] **Step 3: hardware.scad — tray_mount_cuts() を tray_mount_bosses() に置換**

`scad/hardware.scad:43-55`（`tray_mount_cuts` モジュール全体）を、次に置き換える。

```openscad
// トレイを本体天面（内側）から留めるための本体側ボス。tray_fix_pts の各点に、床上面
// （z=wall）から tray_boss_h 立てる。上面から tray_screw_pilot の袋下穴を tray_screw_grip
// 深さで彫る（ドア面 z=0 は貫通させない）。トレイのスリーブが下からこれに被さり、天面から
// M2 セルフタップでキャップ耳をボス上面へ締めるとトレイが固定される。加算形状（union で使う）。
module tray_mount_bosses() {
  for (p = tray_fix_pts)
    translate([p[0], p[1], wall])
      difference() {
        cylinder(d = tray_boss_d, h = tray_boss_h);
        translate([0, 0, tray_boss_h - tray_screw_grip])
          cylinder(d = tray_screw_pilot, h = tray_screw_grip + 0.1);
      }
}
```

- [ ] **Step 4: body.scad — cut から除去し union へボスを追加**

`scad/body.scad` の `mount_plate();`（28 行）の直後に、ボス追加を差し込む。

```openscad
      // bottom mount face with pedestal
      mount_plate();
      // トレイ天面留めの固定ボス（tray_fix_pts に床から立てる。union 側）
      tray_mount_bosses();
    }
```

続けて `difference()` の cut にある旧呼び出し（39〜41 行）を削除する。削除対象:

```openscad
    // tray fastening: clearance holes + head counterbores through the floor
    // (tray は本体裏からネジ留め。位置はワールド座標の tray_fix_pts)
    tray_mount_cuts();
```

- [ ] **Step 5: tray.scad — ポストをスリーブに置換（union solid ＋ difference cut）**

`scad/tray.scad` の union 内、固定ポスト生成（38〜41 行）を次に置き換える。

```openscad
      // 固定スリーブ solid（ボア/ネジ穴は下の difference で彫る）。床下面 z=0 から立て、
      // ボス収容分 + キャップ分の高さ。
      for (p = tray_fix_pts)
        translate([p[0], p[1], 0])
          cylinder(d = tray_sleeve_od, h = tray_boss_h + tray_cap_t);
```

続けて difference の cut にある固定ポスト袋下穴（44〜47 行）を次に置き換える。

```openscad
    // 固定スリーブのボス逃げボア（床貫通〜ボス収容）＋キャップのネジ通し＋頭ザグリ（天面から）
    for (p = tray_fix_pts)
      translate([p[0], p[1], 0]) {
        translate([0, 0, -0.1])
          cylinder(d = tray_sleeve_id, h = tray_boss_h + 0.1);
        translate([0, 0, tray_boss_h - 0.1])
          cylinder(d = tray_screw_clear, h = tray_cap_t + 0.2);
        translate([0, 0, tray_boss_h + tray_cap_t - tray_head_h])
          cylinder(d = tray_head_d, h = tray_head_h + 0.2);
      }
```

冒頭のモジュール説明コメント（4〜8 行）も、裏留め前提の記述を天面留めに直す。`tray.scad:4-8` を次に置き換える。

```openscad
// 電子部品トレイ（ワールド座標＝軸原点フレームで構築）。
// Pico を +Y 天井壁寄りに四隅スタンドオフで浮かせて載せ（両面ピンの下側を床から逃がす）、
// その右へブレッドボードを浅い囲い壁ポケットで落とし込む。四隅付近の固定スリーブが本体床の
// ボスに被さり、天面（内側）から M2 セルフタップでキャップ耳をボス上面へ締めて固定する。
// Pico は四隅穴へ上から M2 セルフタップで固定する。床は translate([0,0,wall]) で本体床上へ。
```

- [ ] **Step 6: tray_pilot_gauge.scad — 母材をボディボスに合わせて更新**

母材がトレイ→ボディに移るので、ゲージのポスト径・高さを `tray_boss_d/tray_boss_h` にし、コメントを整合させる（下穴径 `tray_screw_pilot`・効き代 `tray_screw_grip` は据え置き）。`scad/tray_pilot_gauge.scad:1-11` を次に置き換える。

```openscad
// 本体ボスの M2 自己タップ下穴ゲージ（実際のボス条件を再現）。
// tray_boss_d 径・tray_boss_h 高さのボスを並べ、各ボス上面から tray_screw_grip 深さの
// 袋下穴を設計径 1.7〜2.2mm（0.1刻み）で開ける。印刷して M2 を上からねじ込み、
// 「しっかり効くが割れない」設計値を tray_screw_pilot に採用する。
//
// 平板ゲージ(pilot_gauge.scad)ではなく立てたボス形状にしたのは、深い縦穴が平板の貫通穴と
// 収縮量が違うため（実機で平板由来の 2.2 がポストでは緩かった）。印刷向き：ベースをベッドに
// 置きボスを立てる（本番同等）。下穴は上からの縦穴。
// 識別：小径側の角を落としてある（面取り側が最小径 1.7）。各ボス手前の刻みノッチが左から
// i+1 個 = 何番目か（1個=1.7, 2個=1.8, ...）。
```

続けて 38〜41 行の `tray_fix_d`/`tray_fix_h` を `tray_boss_d`/`tray_boss_h` に置き換える。

```openscad
    difference() {
      cylinder(d = tray_boss_d, h = base_t + tray_boss_h);
      translate([0, 0, base_t + tray_boss_h - tray_screw_grip])
        cylinder(d = gauge_ds[i], h = tray_screw_grip + 0.1);
    }
```

- [ ] **Step 7: smartlock.scad — 既存 tray_coupon の旧シンボル参照を更新**

`scad/smartlock.scad:22-28`（`tray_coupon` パート）の切り出しボックスを、スリーブ寸法基準に更新する。

```openscad
else if (part == "tray_coupon")
  intersection() {
    tray();
    translate([pocket_outer_right - 8, pocket_outer_top - 40, -1])
      cube([tray_fix_x_right + tray_sleeve_od/2 + 3 - (pocket_outer_right - 8),
            40 + 3, tray_boss_h + tray_cap_t + bb_pocket_wall_h + 3]);
  }
```

- [ ] **Step 8: tray.scad 単体を render して NoError を確認**

Run: `./test/render.sh scad/tray.scad`
Expected: 末尾に `OK: /tmp/tray.stl`。`WARNING:` / `ERROR:` / assert 失敗が無いこと。

- [ ] **Step 9: 全パートを build して NoError を確認**

Run: `./build.sh`
Expected: `All parts built to build/`。body / lid / socket / tray / asm_* / tray_pilot_gauge / pilot_gauge が全て Status: NoError。

- [ ] **Step 10: コミット**

```bash
git add scad/params.scad scad/hardware.scad scad/body.scad scad/tray.scad scad/tray_pilot_gauge.scad scad/smartlock.scad
git commit -m "feat(scad): トレイ固定を本体裏留めから天面留め（ボス＋スリーブ）へ

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 2: 嵌合クーポン part の追加

ボス⇔スリーブの横嵌め（`boss_fit`）とセルフタップの効きを、本体まるごと刷らずに検証するための小クーポン。本物の `body()` / `tray()` をそのまま切り出す。

**Files:**
- Modify: `scad/smartlock.scad`（`tray_mount_coupon` パート追加）

**Interfaces:**
- Consumes: `body()`, `tray()`, `tray_fix_x_right`, `tray_fix_y_lo`, `tray_sleeve_od`, `tray_boss_h`, `tray_cap_t`, `wall`。
- Produces: `part == "tray_mount_coupon"` で「本体ボス1本＋トレイスリーブ1個」を X 方向に並べて出力（両方とも床下面 z=0 がベッド接地）。

- [ ] **Step 1: smartlock.scad にクーポン part を追加**

`scad/smartlock.scad` の `tray_coupon` の else-if ブロック直後に、次を挿入する。

```openscad
// 本体ボス1本＋トレイスリーブ1個を並べた嵌合クーポン（横嵌め boss_fit・効き・クランプ確認用）。
// 右下の固定点を本物の body/tray からそのまま切り出す。両方とも床下面 z=0 がベッド接地。
else if (part == "tray_mount_coupon") {
  cx = tray_fix_x_right;
  cy = tray_fix_y_lo;
  hw = tray_sleeve_od/2 + 3;   // 切り出し半幅（隣のポケット縁/壁も少し含む）
  // 本体ボス側（床パッチ＋ボス1本）
  intersection() {
    body();
    translate([cx, cy, (wall + tray_boss_h + 2)/2 - 0.1])
      cube([2*hw, 2*hw, wall + tray_boss_h + 2], center = true);
  }
  // トレイスリーブ側（床パッチ＋スリーブ1個）。印刷用に +X へ退避。
  translate([2*hw + 8, 0, 0])
    intersection() {
      tray();
      translate([cx, cy, (tray_boss_h + tray_cap_t + 2)/2 - 0.1])
        cube([2*hw, 2*hw, tray_boss_h + tray_cap_t + 2], center = true);
    }
}
```

- [ ] **Step 2: クーポンを render して NoError を確認**

Run: `nix develop -c openscad -D 'part="tray_mount_coupon"' -o /tmp/tray_mount_coupon.stl scad/smartlock.scad 2>&1`
Expected: 末尾に `Geometries in cache` などの成功ログ、`WARNING:` / `ERROR:` が無いこと（`Status: NoError` を含む manifold ログ）。非ゼロ終了しないこと。

- [ ] **Step 3: 既存 assembly が壊れていないか確認**

Run: `nix develop -c openscad -D 'part="assembly"' -o /tmp/assembly.stl scad/smartlock.scad 2>&1`
Expected: `WARNING:` / `ERROR:` が無いこと。

- [ ] **Step 4: コミット**

```bash
git add scad/smartlock.scad
git commit -m "feat(scad): ボス⇔スリーブ嵌合クーポン part を追加

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## フェーズ2（印刷して実測 → 反映。コード外の物理作業）

このプランのコード作業はフェーズ1（Task 1–2）まで。以下は印刷後に行う。

1. `tray_mount_coupon` を印刷し、以下を実測・確認する。
   - ボス⇔スリーブの横嵌め：スルッと入りガタつかないか（きつい/緩い）。
   - M2 セルフタップの効き（下穴 `tray_screw_pilot=2.1`・効き代の妥当性。`tray_pilot_gauge` 併用可）。
   - 締結時にキャップ耳がボス上面へ密着し、トレイ相当が浮かずクランプできるか。
   - キャップ耳の座残り（tray_cap_t - tray_head_h = 0.9mm）で M2 パン頭が引き抜けないか。頭が座面に食い込むようなら tray_cap_t を ~3.0 へ増やす（座残り 1.4mm）。
   - 右スリーブ↔+X 壁の余裕が 0.7mm と最小。boss_fit 確定時に viewer で干渉を目視する。
2. 実測から `boss_fit`（必要なら `tray_sleeve_wt` / `tray_cap_t`）を確定し、`params.scad` を更新（コメントに実測値の根拠を残す）。
3. `./test/render.sh scad/tray.scad` と `./build.sh` を再実行して NoError。
4. viewer で目視（`viewer-preview` スキル）。最終的に本体（body / tray）を印刷して組み確認。

## Self-Review（記入済み）

- **Spec coverage:** 方針1（ボディボス＋トレイ耳）=Task1 Step3–5。嵌合クリアランス `boss_fit`=Task1 Step1＋フェーズ2で実測。位置/クリアランス再調整=Task1 Step1–2。嵌合クーポン=Task2。`tray_pilot_gauge` 整合=Task1 Step6。検証（render/build/assert）=各 Step8–9, Task2 Step2–3。ドア面無傷=袋下穴（Step3）＋assert（Step2）。全項目にタスク対応あり。
- **Placeholder scan:** TBD/TODO なし。`boss_fit` の実測はフェーズ2の物理作業として明示（設計値0.4で render は通る）。
- **Type consistency:** `tray_mount_bosses()`（hardware→body で一致）、`tray_sleeve_od`/`tray_sleeve_id`/`tray_boss_h`/`tray_cap_t`（params 定義と tray/smartlock 参照で一致）、旧 `tray_fix_d`/`tray_fix_h` は全参照（tray/gauge/smartlock）を Task1 内で除去済み。
