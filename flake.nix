{
  description = "smtlk smart lock enclosure dev environment";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" ];
      forAll = f: nixpkgs.lib.genAttrs systems (s: f nixpkgs.legacyPackages.${s});
    in {
      devShells = forAll (pkgs: let
        # wokwi-cli は nixpkgs 未収録。GitHub リリースのスタティックバイナリを包む。
        wokwiCliBin = {
          x86_64-linux = {
            suffix = "x64";
            sha256 = "04g873ypgdpxpkzr3vygwg1sd5asp0g79dvsqhr7bbxb1caninbj";
          };
          aarch64-linux = {
            suffix = "arm64";
            sha256 = "1rxi05ci5jj0q1kdh0nx9lr0633vy7lpzcglydmsqkxrdk7w0p90";
          };
        }.${pkgs.stdenv.hostPlatform.system};
        wokwi-cli = pkgs.runCommand "wokwi-cli-0.26.1" {
          src = pkgs.fetchurl {
            url = "https://github.com/wokwi/wokwi-cli/releases/download/v0.26.1/wokwi-cli-linuxstatic-${wokwiCliBin.suffix}";
            inherit (wokwiCliBin) sha256;
          };
        } ''
          mkdir -p $out/bin
          cp $src $out/bin/wokwi-cli
          chmod +x $out/bin/wokwi-cli
        '';
      in {
        default = pkgs.mkShell {
          packages = [
            wokwi-cli         # Wokwi シミュレーション CLI（WOKWI_CLI_TOKEN が必要）
            pkgs.openscad-unstable  # 3D render with Manifold backend (headless via Mesa EGL)
            pkgs.uv           # runs viewer/serve.py (PEP 723), provisions its own Python
            pkgs.cloudflared  # quick tunnel binary (pip's pycloudflared lacks aarch64)
            pkgs.rustup       # Pico W firmware toolchain; rust-toolchain.toml が stable + thumbv6m を自動導入
            pkgs.librsvg      # SVG -> PNG 変換
            pkgs.mesa         # swrast ソフトウェアレンダラ（headless 3D レンダリング用）
            pkgs.libglvnd     # EGL ディスパッチャー
            # デバッグプローブで書き込み/ログするなら probe-rs を追加（nixpkgs の版で attr 名が
            # probe-rs-tools / probe-rs と揺れるので、お使いの nixpkgs に合う方を有効化する）:
            # pkgs.probe-rs-tools
            # cargo の外部サブコマンド。`cargo host-test` で起動され、uname -m でホストトリプルを
            # 動的に解決するため x86_64 / aarch64 どちらの環境でも同じコマンドで動く。
            (pkgs.writeShellScriptBin "cargo-host-test" ''
              shift  # cargo が外部サブコマンドに渡す先頭引数（"host-test"）を除去する
              exec cargo test -p smtlk-core --target "$(uname -m)-unknown-linux-gnu" "$@"
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
