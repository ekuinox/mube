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
            pkgs.openscad     # render .scad -> STL (headless)
            pkgs.python3      # static file server for the viewer
            pkgs.cloudflared  # quick tunnel to expose the viewer
            pkgs.gh           # GitHub CLI (also the git credential helper)
          ];
        };
      });
    };
}
