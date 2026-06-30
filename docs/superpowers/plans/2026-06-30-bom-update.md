# BOM 3 品目追加 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** M2 ネジ・100nF セラミックコンデンサ (C2)・1N5819 ショットキーダイオード (D2) を回路定義と BOM に追加し、#21, #25, #26 を closes する。

**Architecture:** `circuit/netlist.py` に C2・D2 の部品定義と配線を追加し、`docs/parts-selection.md` の BOM 表・概算・購入先まとめを 3 品目分更新する。

**Tech Stack:** Python (netlist.py), Markdown (parts-selection.md), nix develop 経由でテスト実行

## Global Constraints

- テスト実行は `nix develop -c ./test/netlist_test.py`（素の Python では動かない）
- `build/` 以下は派生物、コミットしない
- 秋月電子通商への集約率 100% を維持

---

### Task 1: netlist.py に C2 (100nF セラコン) と D2 (1N5819 ダイオード) を追加

**Files:**
- Modify: `circuit/netlist.py:75-86` (PARTS dict)
- Modify: `circuit/netlist.py:88-99` (PART_META dict)
- Modify: `circuit/netlist.py:102-119` (build_nets 関数)
- Test: `test/netlist_test.py` (既存テストでカバー: `test_real_circuit_passes_erc`, `test_every_part_pin_is_used`)

**Interfaces:**
- Consumes: なし (このタスクが最初)
- Produces: netlist.py の PARTS/PART_META/NETS に C2, D2 が追加された状態。ERC パス済み。

- [ ] **Step 1: 既存テストが green であることを確認**

Run: `nix develop -c ./test/netlist_test.py`
Expected: `all tests passed`

- [ ] **Step 2: PARTS に C2, D2 を追加**

`circuit/netlist.py` の PARTS dict (L85 `"C1"` の後) に追加:

```python
    "C2": ["1", "2"],
    "D2": ["A", "K"],
```

変更後の PARTS dict 末尾:

```python
    "C1": ["+", "-"],
    "C2": ["1", "2"],
    "D2": ["A", "K"],
}
```

- [ ] **Step 3: PART_META に C2, D2 を追加**

`circuit/netlist.py` の PART_META dict (L98 `"C1"` の後) に追加:

```python
    "C2": ("Ceramic cap", "100nF"),
    "D2": ("Schottky diode", "1N5819"),
```

変更後の PART_META dict 末尾:

```python
    "C1": ("Electrolytic cap", "470uF"),
    "C2": ("Ceramic cap", "100nF"),
    "D2": ("Schottky diode", "1N5819"),
}
```

- [ ] **Step 4: build_nets の NETS に C2, D2 の配線を追加**

`circuit/netlist.py` の `build_nets` 関数内、3 つのネットを変更:

`"+5V"` ネット — 末尾に `("C2", "1"), ("D2", "K")` を追加:

```python
        "+5V": [("U1", "VBUS"), ("C1", "+"), ("M1", "V+"), ("C2", "1"), ("D2", "K")],
```

`"GND"` ネット — 末尾に `("C2", "2")` を追加:

```python
        "GND": [("U1", "GND"), ("C1", "-"), ("Q1", "S"),
                ("Rgs", "2"), ("D1", "K"), ("SW1", "2"), ("C2", "2")],
```

`"SERVO_RTN"` ネット — 末尾に `("D2", "A")` を追加:

```python
        "SERVO_RTN": [("M1", "GND"), ("Q1", "D"), ("D2", "A")],
```

- [ ] **Step 5: テストを実行して ERC パスを確認**

Run: `nix develop -c ./test/netlist_test.py`
Expected: `all tests passed`

特に `test_real_circuit_passes_erc` (ERC チェック) と `test_every_part_pin_is_used` (全ピン使用確認) が C2, D2 を自動的に検証する。

- [ ] **Step 6: コミット**

```bash
git add circuit/netlist.py
git commit -m "feat(circuit): C2 (100nF セラコン) と D2 (1N5819 ダイオード) を追加 (closes #25, closes #26)"
```

---

### Task 2: parts-selection.md に 3 品目を追加し概算を更新

**Files:**
- Modify: `docs/parts-selection.md`

**Interfaces:**
- Consumes: Task 1 で netlist.py に C2, D2 が追加済み
- Produces: BOM 17 品目の完全な調達ドキュメント

- [ ] **Step 1: メイン表に 3 行追加**

`docs/parts-selection.md` のメイン表末尾 (L29 `micro-USBケーブル` の後) に 3 行追加:

```markdown
| C2 100nF | 積層セラミックコンデンサー 0.1µF100V X7R 5mmピッチ | 秋月 | [P-15927](https://akizukidenshi.com/catalog/g/g115927/) | ¥120 | 10 | 1 | ¥12 |
| D2 1N5819 | ショットキーバリアダイオード 40V1A 1N5819 | 秋月 | [I-17244](https://akizukidenshi.com/catalog/g/g117244/) | ¥100 | 10 | 1 | ¥10 |
| - M2ネジ (サーボ固定) | なべ小ねじ(+) M2×5 黄銅 | 秋月 | [P-15887](https://akizukidenshi.com/catalog/g/g115887/) | ¥100 | 10 | 2 | ¥20 |
```

- [ ] **Step 2: 概要セクションの品目数を更新**

L6 を変更:

```
変更前: - 範囲: 完成実機に物理的に残る全 14 品目（BOM 9 点＋手配線に要る追加 5 点）。道具・消耗品は対象外。
変更後: - 範囲: 完成実機に物理的に残る全 17 品目（BOM 11 点＋手配線に要る追加 6 点）。道具・消耗品は対象外。
```

L9 の品目数も更新:

```
変更前: - 在庫・販売状況: 2026-06-25 時点で、メイン表 14 品目および備考の代替候補 4 品目すべてが秋月電子で販売中・在庫ありであることを商品ページで確認済み（廃盤なし）。一部は次回入荷待ちの表記があるが注文は可能。
変更後: - 在庫・販売状況: 2026-06-25 時点で、メイン表 17 品目および備考の代替候補 4 品目すべてが秋月電子で販売中・在庫ありであることを商品ページで確認済み（廃盤なし）。一部は次回入荷待ちの表記があるが注文は可能。追加 3 品目（C2, D2, M2ネジ）は 2026-06-30 時点で在庫確認済み。
```

- [ ] **Step 3: 概算サマリを更新**

L33-37 を変更:

```markdown
- ① 1台分の理論按分合計: ¥3,274（按分額列の総和。理論上 1 台が消費する分だけの価値）
- ② 実際に 1 台作るために払う総額: ¥4,425（パック品も丸ごと買う前提の実支出。送料別）
  - 内訳: 秋月 ¥4,425（全点秋月、他店送りなし）
```

残りの 2 行 (送料の目安, 補足) は変更不要。

- [ ] **Step 4: 購入先まとめセクションを更新**

L40 の集約率を変更:

```
変更前: 秋月電子通商で全点購入（集約率 14/14 = 100%）。他店送りなし。
変更後: 秋月電子通商で全点購入（集約率 17/17 = 100%）。他店送りなし。
```

購入先まとめ表の末尾 (L58 `USBケーブル` の後) に 3 行追加:

```markdown
| 秋月電子通商 | [P-15927](https://akizukidenshi.com/catalog/g/g115927/) | 積層セラミックコンデンサー 0.1µF100V X7R 5mmピッチ（10個入, 1個使用） |
| 秋月電子通商 | [I-17244](https://akizukidenshi.com/catalog/g/g117244/) | ショットキーバリアダイオード 40V1A 1N5819（10本入, 1本使用） |
| 秋月電子通商 | [P-15887](https://akizukidenshi.com/catalog/g/g115887/) | なべ小ねじ(+) M2×5 黄銅（10個入, 2個使用） |
```

- [ ] **Step 5: 備考セクションに注意点を追記**

`### 注意点` セクション (L78-83) の末尾に以下を追加:

```markdown
- セラミックコンデンサ（C2）は無極性。C1（電解 470µF）に並列で VBUS-GND 間に配置する。C1 に隣接させること（高周波バイパス効果のため）。
- ショットキーダイオード（D2, 1N5819）はカソード帯（白帯）を +5V 側（M1.V+）に、アノードを SERVO_RTN 側（M1.GND / Q1.D）に接続する。逆に付けるとサーボ電源が短絡するので極性に注意。
- M2 ネジ（なべ小ねじ M2×5）はサーボ耳のネジ穴 2 箇所に使用する。3D プリント筐体の 1.8mm パイロットホールにセルフタップで固定する。締めすぎるとボスが割れるので注意。
```

- [ ] **Step 6: netlist.py 申し送り TODO を更新**

`### netlist.py への申し送り TODO` セクション (L84-86) を更新:

```
変更前: 実機で型番確定後に FET の value を 1 つへ絞り込み、コンデンサ耐圧を value に追記する（本作業では netlist.py は変更しない）。
変更後: 実機で型番確定後に FET の value を 1 つへ絞り込み、コンデンサ耐圧を value に追記する。
```

C2・D2 は netlist.py に追加済みなので「本作業では netlist.py は変更しない」を削除。

- [ ] **Step 7: コミット**

```bash
git add docs/parts-selection.md
git commit -m "docs: BOM に M2ネジ・100nFセラコン・1N5819ダイオードを追加 (closes #21)"
```
