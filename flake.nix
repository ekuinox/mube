{
  description = "smtlk smart lock enclosure dev environment";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" ];
      forAll = f: nixpkgs.lib.genAttrs systems (s: f nixpkgs.legacyPackages.${s});
    in {
      devShells = forAll (pkgs: {
        default = pkgs.mkShell {
          packages = [
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
