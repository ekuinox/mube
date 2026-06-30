# C1: ソケットのシャフトボアを十字ホーンポケットに置換する設計

Issue: #22
親 Issue: #12

## 背景

socket.scad のサーボシャフト穴が `cylinder(d = servo_shaft_d + fit_clearance)` = phi5.2mm の滑らかな円筒ボアとして設計されている。SG90 の出力軸はスプライン形状（歯車状断面）のため、円筒ボアでは噛み合わずトルク伝達時に空転する。

## 方針

SG90 付属の十字ホーンを介してトルクを伝達する。ホーンはスプライン軸に嵌合し（メーカー設計による確実な噛み合い）、ソケット側には十字形のポケットを設けてホーン腕を受ける。

検討した 3 案のうち、この「ホーン + ポケット」方式を採用した理由:
- スプラインの歯形を FDM でモデリングする案は、0.4mm ノズルで歯ピッチ ~0.7mm の再現が困難
- セットスクリュー案は点接触による軸損傷・振動での緩みリスクがある
- ホーン方式は追加購入部品なし（SG90 付属品）、horn_h = 4mm のスペースが既に確保済み

## 変更内容

### 1. params.scad: 十字ホーンパラメータの追加

`// --- SG90 servo ---` セクションの直後に追加:

```openscad
// --- SG90 cross horn (付属十字ホーン, 仮寸法・要実測) ---
horn_arm_l      = servo_tab_l / 2;  // 16.1: 長辺腕の中心→先端 (≈タブ出っ張り)
horn_arm_w      = 2;        // 腕幅 (概算)
horn_hub_d      = 7;        // 中央ハブ外径 (概算)
horn_thick      = 2;        // ホーン厚 (概算)
horn_screw_d    = 2.2;      // 中心ネジ穴径 (概算)
horn_clearance  = 0.3;      // ホーンポケット専用クリアランス (fit_clearance とは独立)
```

- `horn_arm_l` のみ `servo_tab_l` から導出。他は概算初期値
- `horn_clearance` を `fit_clearance` と分離: ホーンポケットの嵌合調整サイクルはサーボ本体のクリアランスとは独立

SG90 のデータシートにはホーン寸法が記載されていないため、実測で確定させる前提。初期値で印刷し、嵌合を見て horn_clearance 等を調整する運用。

### 2. socket.scad: シャフトボアを十字ポケットに置換

現状:
```openscad
// servo shaft bore (bottom)
translate([0, 0, -0.1])
  cylinder(d = servo_shaft_d + c, h = 6 + 0.1);
```

変更後:
```openscad
// cross-horn pocket (bottom face = shaft side when assembled)
hc = horn_clearance;
translate([0, 0, -0.1]) {
  linear_extrude(height = horn_thick + hc + 0.1)
    union() {
      for (a = [0, 90])
        rotate([0, 0, a])
          square([2*(horn_arm_l + hc), horn_arm_w + 2*hc], center = true);
      circle(d = horn_hub_d + 2*hc);
    }
  cylinder(d = horn_screw_d + hc, h = 6 + 0.1);
}
```

- ポケット深さ: `horn_thick + horn_clearance` = 2.3mm。カラー 6mm のうち残り肉厚 ~3.7mm
- 十字腕: 0 deg と 90 deg の 2 本の長方形 + 中央ハブ円
- ネジアクセス穴: カラー全高を貫通。組立時（ソケット反転後）は上からドライバーでホーン固定ネジにアクセス可能

### 3. 他ファイルへの影響: なし

- mount_plate.scad: ホーンはソケット内にリセスされるため、ペデスタルのシャフト穴（phi5.6mm）は変更不要
- smartlock.scad / layout_check.scad: Z 寸法の変更なし。horn_h = 4mm のスペースはそのまま
- hardware.scad: サーボモデルの変更なし

## 寸法上の確認

- ソケット外形: `ow = knob_w_base + knob_t + 2*socket_wall = 35mm`（角 R6 丸め正方形）
- ホーン長辺 tip-to-tip: `2 * horn_arm_l = 32.2mm` — ow 内に 1.4mm の余裕で収まる
- 壁厚が薄くなるのは十字腕方向のみ（対角方向は十分厚い）。サムターン操作トルク程度では問題なし

## スコープ外

- #34 (F2): socket_oh の 3 箇所重複は別イシューで対処
- #21 (B6): ホーン固定ネジは SG90 付属品のため BOM 追加不要
