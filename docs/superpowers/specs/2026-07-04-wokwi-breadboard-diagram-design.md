# Wokwi 配線見本図生成の設計

`circuit/netlist.py` の netlist から Wokwi の `diagram.json` を生成し、ブラウザ（wokwi.com）で見られる配線見本図を作る。wokwi-cli を nix 環境に追加してローカルからの読み込み・シミュレーション確認もできるようにする。

## 背景と方針

- Wokwi の公式部品ライブラリはシミュレーション可能な部品のみで、MOSFET・コンデンサ・ダイオードなどのディスクリート部品は存在しない。
- そこで Chips API のカスタムチップ（`chip.json` でピン名を定義した自作部品）を使い、Q1/C1/C2/D2 も図に含める。カスタムチップは振る舞いを書かなければ「見た目とピンだけの部品」として配置・配線できる。
- これにより netlist の NETS を簡略化せず全 net をそのまま配線する。図とネットリストの構造が 1:1 で対応する。
- 配線はブレッドボード部品を経由せずピン同士を直接ワイヤで結ぶ（穴番号割り付けの自動レイアウトは初版では作らない。物足りなければ次段で検討）。
- tscircuit は今回のスコープ外（別実験として将来検討）。

## 成果物

### circuit/wokwi.py（新規）

PEP 723 の uv スクリプト・依存ゼロ。`netlist.py` から `PARTS` / `NETS` / `PART_META` / `GPIO` を import して以下を生成する。

- `build/wokwi/diagram.json` — 全部品・全 net の配線図
- `build/wokwi/chips/*.chip.json` — カスタムチップ定義（MOSFET / 電解コン / セラコン / ショットキー）
- `build/wokwi/notes.md` — カスタムチップは見た目が汎用 IC ボディである旨と、実部品（型番）との対応表

部品タイプ対応:

| ref | Wokwi 部品 |
| --- | --- |
| U1 | `board-pico-w` |
| M1 | `wokwi-servo` |
| Rg / Rgs / Rled / Rled2 | `wokwi-resistor`（value 属性つき） |
| D1 | `wokwi-led` ×2（赤・緑。共通カソードの 2 色 LED を 2 個で表現し、notes.md に注記） |
| SW1 | `wokwi-pushbutton` |
| Q1 / C1 / C2 / D2 | カスタムチップ（`chip-mosfet` G/D/S、`chip-cap-pol` +/-、`chip-cap` 1/2、`chip-schottky` A/K） |

レイアウトとワイヤ:

- 固定レイアウト（Pico 中央、左に LED・ボタン、右にサーボ・MOSFET 周り）。座標はスクリプト内の定数。
- ワイヤ色は net 種別で分ける: +5V=赤、GND=黒、信号 net は互いに区別できる色。
- 各 net は netlist の endpoint 列を from-to.md と同じ隣接ペアの連鎖として配線する。

### wokwi-cli 連携

- `circuit/wokwi/wokwi.toml` — wokwi-cli 用プロジェクト設定。ファームは既存 Rust ファームのビルド成果物（ELF/UF2）を指す。
- 動作確認のゴールは「diagram.json が読み込めて、ファームが起動してパニックしない」レベル。WiFi 接続の成否までは追わない。
- トークンは環境変数 `WOKWI_CLI_TOKEN` で渡す。コミットしない（秘密の取り扱いは WiFi 認証と同様）。

### nix（flake.nix）

- wokwi-cli は nixpkgs に無いため、GitHub リリースのスタティックバイナリ（linuxstatic-x64 / linuxstatic-arm64）を `fetchurl` + ラッパーで包む小さな派生を devShell に追加する。system ごとに URL と hash を切り替える。

### ビルド統合・テスト

- `build.sh` に `circuit/wokwi.py` の実行を追加（from-to/bom と同じ流れで build/ へ出力）。
- テスト（`test/netlist_test.py` と同様の形式）:
  - 生成した diagram.json が JSON として妥当
  - 全 connection の端点が、配置済み部品の実在ピンを指す
  - NETS の全 endpoint が diagram.json の接続として過不足なく現れる
- ERC は従来どおり netlist.py 側の責務。wokwi.py は ERC 通過後のデータを前提とする。

## エラー処理

- 部品タイプ対応表に無い ref が netlist に増えた場合、黙って落とさず stderr に警告を出し、notes.md に「未対応部品」として記録する（見えない欠落を作らない）。
- ピン名がマッピングできない場合はエラーで exit 1（生成物が壊れているのに成功扱いにしない）。

## スコープ外

- ブレッドボード部品（`wokwi-breadboard-half`）への穴割り付け
- tscircuit での回路図生成
- Wokwi 上での WiFi/TCP 通信の完全なシミュレーション
