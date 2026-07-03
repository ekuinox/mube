# サーボ耳マウント再設計＋耳クーポン 実装プラン (Issue #52)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** SG90 サーボ耳の M2 ネジが 3mm 以上効くようにペデスタル天板を作り直し、実機確認用の薄型テストプリント `mount_coupon` パートを追加する。

**Architecture:** 突き出し耳ボスを廃止し、天板を `wall`(2.4mm) から `servo_plate_t`(3.5mm) に増厚して貫通下穴を直接開ける。クーポンは `socket_coupon` と同様に本物の `body()` を天板付近だけ intersection で切り出す（コピーモデルを作らない）。

**Tech Stack:** OpenSCAD（nix dev シェル内）。検証は params.scad の assert と `./test/render.sh` / `./build.sh`。

## Global Constraints

- OpenSCAD は nix dev シェル内のみ。素の `openscad` は `nix develop -c openscad ...` で実行（`.sh` スクリプトは自前で再突入するのでそのまま可）。
- `build/` と `*.stl` はコミットしない（.gitignore 済み）。
- レンダリングは全パート WARNING/ERROR なし（`render.sh` / `build.sh` が検出して FAIL する）。
- 寸法の根拠: 天板上面 Z=pedestal_top_z(42) は不変。ソケット上面は Z = pedestal_top_z − horn_h = 38 を回転（半径 17mm 超）するため、天板下面 38.5 とのクリアランスは horn_h − servo_plate_t = 0.5mm。M2x6 はタブ厚 2.5 + 天板 3.5 = 6.0 でちょうど面一。

---

### Task 1: 耳ボス廃止＋天板増厚（params.scad / mount_plate.scad）

**Files:**
- Modify: `scad/params.scad:19-20`（servo_boss_d / servo_boss_h → servo_plate_t）
- Modify: `scad/params.scad:107`（assert 差し替え）
- Modify: `scad/mount_plate.scad:31-46`（天板増厚＋下穴、ボス for ループ削除）

**Interfaces:**
- Consumes: 既存パラメータ `pedestal_top_z`, `horn_h`, `servo_screw_span`, `servo_screw_pilot`, `servo_shaft_d`, `rosette_d`, `pedestal_wall_t`, `fit_clearance`, `wall`
- Produces: パラメータ `servo_plate_t = 3.5`（Task 2 のクーポン切り出し範囲が参照する）。`mount_plate()` の外部形状（天板上面 Z=42）は不変。

- [ ] **Step 1: params.scad の耳ボス定数を servo_plate_t に差し替え**

`scad/params.scad` の 19-20 行目:

```scad
servo_boss_d      = 4.5;   // 耳ボス外径（Pico ボスと同径。ポケット/タブ干渉を回避）
servo_boss_h      = 4.5;   // pedestal_top からの耳ボス高さ。実効ネジ噛み合いは sg90_cutout のタブスロット(Z≈22.6..25.9)がボス(Z≈23..27.5)を削るため上側 ~1.6mm のみ。M2 には浅く、ボス配置ごと要実測・要設計見直し
```

を次の 1 行に置き換える:

```scad
servo_plate_t     = 3.5;   // 耳ネジが効くペデスタル天板の厚み。下穴は貫通で M2 実効噛み合い = 3.5mm。天板下面とソケット上面(Z=pedestal_top_z-horn_h)のすき間 = horn_h - servo_plate_t = 0.5mm。M2x6 はタブ厚2.5+3.5=6.0で面一
```

- [ ] **Step 2: params.scad の assert を差し替え**

107 行目:

```scad
assert(servo_screw_pilot < servo_boss_d, "pilot hole smaller than boss");
```

を次の 3 行に置き換える:

```scad
assert(servo_plate_t >= 3, "耳ネジの実効噛み合い（天板厚）>= 3mm");
assert(horn_h - servo_plate_t >= 0.5, "天板下面とソケット上面のクリアランス >= 0.5mm");
assert(servo_screw_pilot < servo_plate_t + 2, "下穴径が天板に対して常識的な範囲");
```

（3 本目は boss 前提だった旧 assert の後継。下穴径がタブ穴径オーダーであることの粗い健全性チェック）

- [ ] **Step 3: mount_plate.scad の天板を増厚し、下穴を開け、ボスを削除**

`scad/mount_plate.scad` の 31-46 行目（platform ブロックと bosses ブロック）:

```scad
      // pedestal top platform — disc with shaft hole
      translate([0, 0, pedestal_top_z - wall])
        linear_extrude(height = wall)
          difference() {
            circle(r = pedestal_r);
            circle(d = servo_shaft_d + 2*c);
          }

      // servo screw bosses on pedestal top
      for (sx = [-1, 1])
        translate([sx * servo_screw_span/2, 0, pedestal_top_z])
          difference() {
            cylinder(d = servo_boss_d, h = servo_boss_h);
            translate([0, 0, -0.1])
              cylinder(d = servo_screw_pilot, h = servo_boss_h + 0.2);
          }

```

を次に置き換える:

```scad
      // pedestal top platform — thick disc the servo tabs screw straight into.
      // M2 self-tapping engages the full servo_plate_t (pilot holes are through;
      // the socket top rotating below keeps horn_h - servo_plate_t of clearance).
      translate([0, 0, pedestal_top_z - servo_plate_t])
        linear_extrude(height = servo_plate_t)
          difference() {
            circle(r = pedestal_r);
            circle(d = servo_shaft_d + 2*c);
            for (sx = [-1, 1])
              translate([sx * servo_screw_span/2, 0])
                circle(d = servo_screw_pilot);
          }

```

- [ ] **Step 4: 全パートをレンダリングして NoError を確認**

Run: `./build.sh`
Expected: 全パート（body/lid/socket/asm_*）が `Status: NoError` で `All parts + netlist built to build/`。`servo_boss` 未定義エラーが出たら参照の消し忘れ（`grep -rn servo_boss scad/` で確認して除去）。

- [ ] **Step 5: コミット**

```bash
git add scad/params.scad scad/mount_plate.scad
git commit -m "feat(scad): 耳ボスを廃止し天板増厚＋貫通下穴で M2 噛み合い 3.5mm を確保 (#52)

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 2: mount_coupon パート追加（smartlock.scad）

**Files:**
- Modify: `scad/smartlock.scad:18-24`（socket_coupon 分岐の直後に追加）

**Interfaces:**
- Consumes: Task 1 の `servo_plate_t`、既存の `pedestal_top_z`, `rosette_d`, `pedestal_wall_t`, `fit_clearance`、`body()`
- Produces: `part == "mount_coupon"` でレンダリングできる薄型クーポン（天板そのもの＋実下穴。プリントベッドに接地するよう Z=0 へ平行移動済み）

- [ ] **Step 1: smartlock.scad に mount_coupon 分岐を追加**

`scad/smartlock.scad` の socket_coupon 分岐:

```scad
// ポケット周辺のみ切り出した薄型クーポン（ホーンフィット確認用）
else if (part == "socket_coupon")
  intersection() {
    thumbturn_socket();
    linear_extrude(height = horn_thick + horn_clearance + socket_wall + 0.5) // +0.5 = ポケット底面上のマージン
      square([200, 200], center = true);
  }
```

の直後に追加する:

```scad
// ペデスタル天板のみ切り出した薄型クーポン（サーボ耳の位置・ネジ効き確認用）
else if (part == "mount_coupon")
  translate([0, 0, -(pedestal_top_z - servo_plate_t)]) // 天板下面をベッドに接地
    intersection() {
      body();
      translate([0, 0, pedestal_top_z - servo_plate_t])
        // 半径をペデスタル外周までに絞り、body の外壁を巻き込まない
        cylinder(r = rosette_d/2 + pedestal_wall_t + fit_clearance + 0.1,
                 h = servo_plate_t + 0.5); // +0.5 = 天板上面のマージン
    }
```

- [ ] **Step 2: mount_coupon をレンダリングして NoError を確認**

Run: `nix develop -c openscad -D 'part="mount_coupon"' -o /tmp/mount_coupon.stl scad/smartlock.scad`
Expected: 終了コード 0、出力に `WARNING:` / `ERROR:` なし（`Status: NoError` を含む）。/tmp/mount_coupon.stl が生成される（直径 ~51mm・厚 3.5mm の円盤に下穴 2 個＋シャフト穴）。

- [ ] **Step 3: 既存パートが壊れていないことを確認**

Run: `./build.sh`
Expected: 全パート `Status: NoError`、`All parts + netlist built to build/`。

- [ ] **Step 4: コミット**

```bash
git add scad/smartlock.scad
git commit -m "feat(scad): 耳フィット確認用の mount_coupon パートを追加 (#52)

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

## プリント後のフォローアップ（プラン外・手動）

1. お兄ちゃんの実測（耳ネジ穴の中心間距離 / タブのネジ穴径 / タブ厚 / 手持ち M2 ネジ長）が来たら `servo_screw_span` / `servo_screw_pilot` / `servo_tab_h` / `servo_plate_t` を更新して mount_coupon だけ刷り直す。
2. フィット確定後、実測値込みで PR を出して Issue #52 をクローズする。

---

## 実装後の注記（2026-07-03）

Task 1 / Task 2 は本プラン通り完了。その後の実機採寸で追加の変更（軸オフセット・貫通穴・高さ再計算）が入った。詳細は設計書の「実装後の追記」を参照。
