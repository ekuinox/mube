{
  description = "mube smart lock enclosure dev environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    # rustup の代わりに素の Rust ツールチェーンバイナリを供給する（TASK-9 対策）。
    # rustup のシム経由だと環境変数 RUSTUP_TOOLCHAIN が rust-toolchain.toml より
    # 優先され、外部環境の値でビルドが壊れる。rust-overlay の cargo/rustc は
    # 実バイナリなので RUSTUP_TOOLCHAIN の影響を受けない。
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, rust-overlay }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" ];
      forAll = f: nixpkgs.lib.genAttrs systems (s: f (import nixpkgs {
        system = s;
        overlays = [ rust-overlay.overlays.default ];
      }));
    in {
      devShells = forAll (pkgs: {
        default = pkgs.mkShell {
          packages = [
            pkgs.openscad-unstable  # 3D render with Manifold backend (headless via Mesa EGL)
            pkgs.cloudflared  # quick tunnel binary (pip's pycloudflared lacks aarch64)
            # Pico W firmware toolchain。rust-toolchain.toml（stable + thumbv6m/wasm32 +
            # rust-src/llvm-tools）をそのまま解釈して同等のツールチェーンを提供する。
            # channel = "stable" は flake.lock の rust-overlay スナップショット時点の
            # 最新 stable に解決される（更新は `nix flake update rust-overlay`）。
            (pkgs.rust-bin.fromRustupToolchainFile ./rust-toolchain.toml)
            pkgs.bun          # tscircuit/ の TS 回路記述を実行（tsci は bun 管理の npm パッケージ）
            pkgs.trunk            # yew(WASM) を dist へビルド（crates/mube-webui）
            pkgs.wasm-bindgen-cli # trunk が使う wasm-bindgen を Nix から供給（trunk のネット取得を避ける）
            pkgs.binaryen         # wasm-opt（release 最適化）
            # Backlog.md（backlog/ の残タスク管理 CLI）。nixpkgs 未収載で、GitHub リリースの
            # linux-arm64 バイナリは実行すると素の bun として振る舞い壊れていたため（v1.48.0 で確認）、
            # バージョン固定の bunx ラッパーで提供する。初回実行時のみ bun キャッシュへの取得が走る。
            (pkgs.writeShellScriptBin "backlog" ''
              exec ${pkgs.bun}/bin/bunx backlog.md@1.48.0 "$@"
            '')
            pkgs.librsvg      # SVG -> PNG 変換
            pkgs.mesa         # swrast ソフトウェアレンダラ（headless 3D レンダリング用）
            pkgs.libglvnd     # EGL ディスパッチャー
            # デバッグプローブで書き込み/ログするなら probe-rs を追加（nixpkgs の版で attr 名が
            # probe-rs-tools / probe-rs と揺れるので、お使いの nixpkgs に合う方を有効化する）:
            pkgs.probe-rs-tools  # デバッグプローブ（CMSIS-DAP 等）での書き込み/defmt ログ
            # cargo の外部サブコマンド。`cargo host-test` で起動され、uname -m でホストトリプルを
            # 動的に解決するため x86_64 / aarch64 どちらの環境でも同じコマンドで動く。
            (pkgs.writeShellScriptBin "cargo-host-test" ''
              shift  # cargo が外部サブコマンドに渡す先頭引数（"host-test"）を除去する
              exec cargo test -p mube-core --target "$(uname -m)-unknown-linux-gnu" "$@"
            '')
          ];
          FONTCONFIG_FILE = let
            fontconfig = pkgs.makeFontsConf {
              fontDirectories = [ pkgs.noto-fonts-cjk-sans ];
            };
          in fontconfig;
          # Mesa EGL headless rendering (X/xvfb 不要)
          EGL_PLATFORM = "surfaceless";
          LIBGL_DRIVERS_PATH = "${pkgs.mesa}/lib/dri";
          __EGL_VENDOR_LIBRARY_DIRS = "${pkgs.mesa}/share/glvnd/egl_vendor.d";
          LD_LIBRARY_PATH = "${pkgs.mesa}/lib:${pkgs.libglvnd}/lib";
        };
      });
    };
}
