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
            pkgs.openscad     # render .scad -> STL (headless); cannot be pip-installed
            pkgs.uv           # runs viewer/serve.py (PEP 723), provisions its own Python
            pkgs.cloudflared  # quick tunnel binary (pip's pycloudflared lacks aarch64)
            pkgs.rustup       # Pico W firmware toolchain; rust-toolchain.toml が stable + thumbv6m を自動導入
            # デバッグプローブで書き込み/ログするなら probe-rs を追加（nixpkgs の版で attr 名が
            # probe-rs-tools / probe-rs と揺れるので、お使いの nixpkgs に合う方を有効化する）:
            # pkgs.probe-rs-tools
          ];
        };
      });
    };
}
