# MOSFET 3.3V ゲート駆動 現状維持＋根拠明記 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Q1 (IRLB3813PBF) を回路変更せず維持し、3.3V ゲート駆動の定量根拠・実機計測手順・受け入れ基準を `docs/parts-selection.md` に明記して Issue #24 をクローズする。

**Architecture:** 純ドキュメント変更。`docs/parts-selection.md` の「### MOSFET の注意（重要）」節 1 つを書き換えるのみ。回路ネットリスト・テスト・SCAD・ファームには一切触れない。変更が回路の派生物に波及していないことを既存テストで確認する。

**Tech Stack:** Markdown（ドキュメント）、Python netlist テスト（`./test/netlist_test.py`）、`./build.sh`（回帰確認用）。

## Global Constraints

- 調達は秋月電子に全 16 品集約・スルーホール／手配線。型番 `IRLB3813PBF`（秋月 I-06270）は変更しない。
- データシート実値（出典: Infineon IRLB3813）: Vgs(th) min 1.35V / typ 1.9V / max 2.35V、Rds(on) @ Vgs=4.5V = 2.6mΩ max、@ Vgs=10V = 1.95mΩ max。これらの数値は本文にこのまま使う。
- 受け入れ基準のしきい値はピーク負荷で Vds ≤ 0.2V（実効サーボ電圧 ≥ 4.8V、SG90 定格 4.8〜6V 内）。
- 変更は `docs/parts-selection.md` の 1 節に限定する。コード・テスト・SCAD は変更しない。

---

### Task 1: parts-selection.md の MOSFET 注意節を書き換え

**Files:**
- Modify: `docs/parts-selection.md`（「### MOSFET の注意（重要）」節の本文段落）

**Interfaces:**
- Consumes: なし（独立したドキュメント変更）。
- Produces: なし（後続タスクなし）。

- [ ] **Step 1: 現在の節の本文を確認する**

Run: `grep -n "MOSFET の注意" docs/parts-selection.md`
Expected: 「### MOSFET の注意（重要）」の行番号が 1 件返る。直後の段落が以下であることを確認:

```
第一候補の IRLZ44N は秋月取扱なし。採用した IRLB3813PBF は Vgs(th) 最大 2.35V で Pico W の 3.3V GPIO で閾値は超えられるが、フル導通には 4.5V 以上が望ましく、3.3V 駆動時は Rds(on) が増える。サーボ電源ゲート（低頻度 ON/OFF）では実用上許容の見込みだが、購入前・実装時に 3.3V ゲート駆動の導通特性を要確認。
```

- [ ] **Step 2: 節の本文を新しい内容へ置換する**

`### MOSFET の注意（重要）` 見出しはそのまま残し、直後の 1 段落を以下のブロックで丸ごと置き換える（Edit の old_string は Step 1 で確認した段落全体、new_string は以下）:

```markdown
第一候補の IRLZ44N は秋月取扱なしのため、採用品は IRLB3813PBF（秋月 I-06270, N-ch 30V/260A）。Q1 はサーボの GND リターン（SERVO_RTN）を切るローサイドスイッチで、ゲートは Pico W の GP14（3.3V）から Rg(220Ω) 経由で駆動し Rgs(10k) でプルダウン、給電時のみ ON のワンショット（約 500ms）。

**3.3V ゲート駆動の評価（現状維持の根拠, Issue #24）**

データシート実値（Infineon IRLB3813）: Vgs(th) min 1.35V / typ 1.9V / max 2.35V、Rds(on) @ Vgs=4.5V = 2.6mΩ(max)、@ Vgs=10V = 1.95mΩ(max)。Rds(on) が Vgs=4.5V で規定されている点が、本品がロジックレベル MOSFET であることの裏付け。

- 十分にオンする: Vgs=3.3V のゲートオーバードライブは typ 閾値 1.9V に対し約 1.4V、最悪の閾値 max 2.35V でも約 0.95V。3.3V でエンハンスメント領域に入る。
- 電圧降下は無視できる: 3.3V は Rds(on) 規定点(4.5V)をわずかに下回るのみ。保守的に Rds(on) を高々数十 mΩ と見積もっても、SG90 の起動・失速ピーク（〜1A 程度）での降下は最悪約 50mV、実際は 10mV 前後で、5V 供給に対し無視できる。
- 発熱も無視できる: ワンショット 500ms のため、ピーク電力は P = I²·Rds(on) ≒ 1²×0.05 = 50mW 程度で問題にならない。

**実機ブリングアップ時の確認手順（受け入れ条件）**

1. サーボを動作させ、可能なら失速させてピーク電流を引かせる。
2. その状態で Q1 のドレイン-ソース間電圧 Vds を計測する。
3. 受け入れ基準: ピーク負荷で Vds ≤ 0.2V（5V 供給から実効サーボ電圧 ≥ 4.8V を確保、SG90 定格 4.8〜6V 内）。
4. 基準超過時: ロジックレベル品（Vgs(th) が低いスルーホール・秋月入手可の N-FET）への差し替え、または小信号トランジスタ等でゲートを 5V までスイングし Vgs≥4.5V を保証する 5V ゲート駆動の追加を検討する。
```

- [ ] **Step 3: 差分が当該 1 節に限定されていることを確認する**

Run: `git diff --stat docs/parts-selection.md && git diff docs/parts-selection.md | grep -E '^\+|^-' | grep -iv 'mosfet\|irlb\|irlz\|vgs\|rds\|3.3v\|ゲート\|サーボ\|vds\|オン\|降下\|発熱\|失速\|ロジックレベル\|データシート\|閾値\|オーバードライブ\|ワンショット\|受け入れ\|ブリングアップ\|ピーク\|エスカレーション\|第一候補\|秋月\|i-06270\|sg90\|gp14\|rg\|rgs\|servo_rtn\|プルダウン\|計測'`
Expected: 変更が `docs/parts-selection.md` のみ（`git diff --stat` で 1 file changed）。grep の最終フィルタは目視補助で、想定外の無関係行が無いことを確認する。

- [ ] **Step 4: 回路の派生物に波及がないことを確認する（回帰テスト）**

Run: `nix develop -c ./test/netlist_test.py`
Expected: テストが緑（exit 0）。

Run: `./build.sh && grep -c IRLB3813PBF build/bom.md`
Expected: ビルド成功し、生成 BOM に `IRLB3813PBF` が引き続き出力される（カウント ≥ 1）。`build/` は派生物なのでコミットしない。

- [ ] **Step 5: Commit**

```bash
git add docs/parts-selection.md
git commit -m "docs(parts): MOSFET 3.3V ゲート駆動の根拠と実機計測基準を明記 (closes #24)"
```

---

## Self-Review

- **Spec coverage:** spec の「変更内容」(parts-selection.md の MOSFET 節書き換え) = Task 1 Step 2。「定量根拠」「計測手順・受け入れ基準」= Step 2 の new_string 本文。「検証」(差分限定・回路派生物不変) = Step 3/4。「スコープ外」(コード・テスト・SCAD 不変) = Global Constraints と Step 3 の差分確認で担保。網羅 OK。
- **Placeholder scan:** TBD/TODO なし。置換本文は全文記載済み。
- **Type consistency:** コード型なし（ドキュメントのみ）。数値（2.35V / 2.6mΩ / 0.2V 等）は spec・Global Constraints と一致。
