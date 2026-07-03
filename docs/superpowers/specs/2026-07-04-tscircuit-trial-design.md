# tscircuit お試し環境の設計

日付: 2026-07-04
ステータス: 承認待ち

## 目的

回路 as code ツール tscircuit を smtlk リポジトリ内で試す。
既存の `circuit/netlist.py`（Python 製 ERC ライト + from-to/bom 生成）と同じ回路を tscircuit で記述し、
将来の置き換え判断の材料にする。今回は「お試し」であり、`circuit/netlist.py` は残す。

## 環境（flake.nix）

- default devShell に `pkgs.bun` を追加する。Node.js は追加しない（bun 単独のミニマル構成。足りなければ後で足す）。
- `@tscircuit/cli`（tsci）と `tscircuit` は nixpkgs に無いため、npm パッケージとして
  `tscircuit/` ディレクトリの package.json で管理し、bun でインストールする。
- `bun.lock` はコミットして再現性を保つ。

## 配置（新ディレクトリ `tscircuit/`）

- `package.json` / `bun.lock` — `tscircuit` と `@tscircuit/cli` を devDependency に持つ。
- `index.tsx` — 回路本体。`circuit/netlist.py` と同じ構成を tscircuit コンポーネントで記述する:
  - U1: Raspberry Pi Pico W（既製フットプリントが無ければ pinheader / chip で代用。
    回路図としての正しさを優先し、基板レイアウトの精密さは求めない）
  - M1: SG90 サーボ（3 ピンコネクタとして表現）
  - Q1: N-ch MOSFET（IRLB3813PBF、ローサイドで SERVO_RTN をゲート）
  - Rg 220R / Rgs 10k / Rled・Rled2 330R
  - D1: 2 色 LED（R/YG、カソードコモン）
  - SW1: タクトスイッチ
  - C1 470uF 電解 / C2 100nF セラミック
  - D2: ショットキー 1N5819（+5V → SERVO_RTN の還流）
  - ネット名は netlist.py と揃える: +5V / GND / SERVO_RTN / SERVO_SIG / GATE_DRV / GATE /
    LED_DRV_R / LED_A_R / LED_DRV_G / LED_A_G / BTN
  - GPIO 割当も netlist.py と同じ: servo=GP15, gate=GP14, led_r=GP16, led_g=GP18, btn=GP17
- `.gitignore` に `tscircuit/node_modules/` と生成物（`tscircuit/dist/` 等）を追加する。

## 動かし方・成功条件

- `nix develop -c bun install`（tscircuit/ 内）が通る。
- `nix develop -c bunx tsci build` が通り、circuit.json が生成される。ここまでが本タスクの完了条件。
- プレビューは `tsci dev` のローカルサーバー（LAN からブラウザで見る想定）。
  起動コマンドは tscircuit/ 配下の README か package.json scripts に記す。

## やらないこと

- `circuit/netlist.py` の削除・置き換え（動かしてから判断する）。
- 基板レイアウト（部品配置・配線）の作り込み。
- CI / build.sh への組み込み。
