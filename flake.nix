{
  description = "A very basic flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils, ... }: 
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
        gems = pkgs.bundlerEnv {
          name = "elovation";
          ruby = pkgs.ruby;
          gemdir = ./.;
        };
      in {
        packages = {
          elovation-src = pkgs.stdenv.mkDerivation {
            name = "elovation-src";
            src = ./.;
            installPhase = ''
              mkdir -p $out/src/
              find . -type f -exec install -Dm 755 "{}" "$out/src/{}" \;
            '';
          };
          elovation-rails = pkgs.writeShellApplication {
            name = "elovation-rails";
            runtimeInputs = [ gems ];
            text = ''
              ELOVATION_SRC=${self.packages.${system}.elovation-src}/src
              # Rails sucks ass and requires a writeable tmp dir in the root of the source directory
              # Copy the source out to a writeable path and then execute from there
              TMPDIR=$(mktemp -d)
              cp -r --no-preserve=mode,ownership "$ELOVATION_SRC" "$TMPDIR/app"

              pushd "$TMPDIR/app"
              rails "$@"
              popd
            '';
          };
          default = self.packages.${system}.elovation-rails;
        };
        devShells.default = pkgs.mkShell {
          buildInputs = [
            pkgs.bundix
            pkgs.ruby
            gems
          ];
        };
      });
}
