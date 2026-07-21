# CYW43 ファームウェアブロブ

Pico W の無線チップ CYW43439 は、起動時にファームウェア／NVRAM／CLM のバイナリを読み込む
必要がある。これらは Infineon のライセンス物で、`src/main.rs` から `aligned_bytes!` で
埋め込んでいる。リポジトリには**コミットしていない**（`.gitignore` 済み）。

cyw43 0.7.0 では **3 つとも必須**:
- `43439A0.bin`（firmware）と `nvram_rp2040.bin`（基板 NVRAM）を `cyw43::new(.., fw, nvram)` へ
- `43439A0_clm.bin`（国別 CLM）を `control.init(clm)` へ

NVRAM を渡さない／CLM で代用すると、起動が `waiting for HT clock` で止まる。

ビルド前に embassy リポジトリから取得してこのディレクトリに置くこと。**crate と同じ rev**
（`cyw43-v0.7.0` タグ）から取ってバージョンを揃える:

    BASE=https://raw.githubusercontent.com/embassy-rs/embassy/cyw43-v0.7.0/cyw43-firmware
    curl -fL -o 43439A0.bin       "$BASE/43439A0.bin"
    curl -fL -o 43439A0_clm.bin   "$BASE/43439A0_clm.bin"
    curl -fL -o nvram_rp2040.bin  "$BASE/nvram_rp2040.bin"

置いた後のレイアウト:

    crates/mube-firmware/cyw43-firmware/
      ├── 43439A0.bin       # WiFi ファームウェア
      ├── 43439A0_clm.bin   # 国別 CLM
      ├── nvram_rp2040.bin  # 基板 NVRAM（クロック・電源設定）
      └── README.md         # このファイル
