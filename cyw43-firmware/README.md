# CYW43 ファームウェアブロブ

Pico W の無線チップ CYW43439 は、起動時にファームウェア／CLM／（BT を使うなら）BT FW
のバイナリを読み込む必要がある。これらは Infineon のライセンス物で、`src/main.rs` から
`include_bytes!` で埋め込んでいる。リポジトリには**コミットしていない**（`.gitignore` 済み）。

ビルド前に embassy リポジトリから取得してこのディレクトリに置くこと:

    # 必要なのは最低限この2つ
    BASE=https://raw.githubusercontent.com/embassy-rs/embassy/main/cyw43-firmware
    curl -L -o 43439A0.bin     "$BASE/43439A0.bin"
    curl -L -o 43439A0_clm.bin "$BASE/43439A0_clm.bin"

置いた後のレイアウト:

    cyw43-firmware/
      ├── 43439A0.bin       # WiFi ファームウェア
      ├── 43439A0_clm.bin   # 国別 CLM
      └── README.md         # このファイル

embassy を rev 固定する場合は、`main` ではなくその rev の `cyw43-firmware/` から取得して
バージョンを揃えること。
