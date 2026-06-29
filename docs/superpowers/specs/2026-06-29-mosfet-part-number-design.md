# MOSFET 型番の不一致解消（Issue #17）

## 背景

`circuit/netlist.py` の `PART_META["Q1"]` は MOSFET 型番を `"AO3400 / IRLZ44N"`（候補段階の表記）のまま保持している。一方、実機の購入品は `docs/parts-selection.md` で `IRLB3813PBF`（秋月 I-06270）に確定済み。回路定義と調達ドキュメントの型番が一致しておらず、netlist から生成される BOM が実部品と食い違う。

親 Issue: #12 / 対象 Issue: #17

## 目的

`netlist.py` の Q1 型番を確定済みの実購入品 `IRLB3813PBF` に揃え、netlist 由来の BOM と `parts-selection.md` を一致させる。

## 変更内容（2 ファイル・3 行）

1. `circuit/netlist.py`（91 行目付近）
   - `"Q1": ("N-ch MOSFET (logic level)", "AO3400 / IRLZ44N"),`
   - → `"Q1": ("N-ch MOSFET (logic level)", "IRLB3813PBF"),`

2. `test/netlist_test.py`（67 行目付近）
   - fixture の Q1 値 `"AO3400 / IRLZ44N"` → `"IRLB3813PBF"`

3. `test/netlist_test.py`（71 行目付近）
   - アサート文字列 `| Q1 | N-ch MOSFET (logic level) | AO3400 / IRLZ44N | 1 |`
   - → `| Q1 | N-ch MOSFET (logic level) | IRLB3813PBF | 1 |`

## 判断の根拠

- **値は型番のみ（`"IRLB3813PBF"`）**: 他品目（D1 = `"OSRGHC5B32A"` など）が型番単独で書かれている流儀に合わせる。秋月通販コード `I-06270` は `parts-selection.md` に既出のため、netlist 側で二重管理しない。
- **説明 `"N-ch MOSFET (logic level)"` は維持**: IRLB3813PBF も Vgs(th) が低めのロジックレベル寄り MOSFET であり、`parts-selection.md` の注意書き（3.3V ゲート駆動でも閾値は超えるが Rds(on) は増える、低頻度 ON/OFF では実用可の見込み）の通り表現として妥当。
- **テスト fixture は型番更新のみ**: `test_gen_bom_rows` の `meta` は `gen_bom` の整形を検証するローカル fixture で、`PART_META` を import していないため厳密にはテストは落ちない。ただし旧型番がコード上に残ると実態とズレるため、fixture 値も同時に更新して整合させる。

## 検証

- `nix develop -c ./test/netlist_test.py` が緑であること。
- `./build.sh` で netlist を再生成し、生成 BOM に `IRLB3813PBF` が出力されることを確認。

## スコープ外

- `docs/superpowers/` 配下の過去 plan/spec: 作業記録（履歴）なので変更しない。
- SCAD 側の `mosfet_l` / `mosfet_w` / `mosfet_space()`: 筐体のキープアウト寸法であり型番に依存しないため対象外。
- README: MOSFET 型番の記載はなく変更不要。
