{
  description = "flac — Zig 0.16 wrapper around libFLAC (static lib + headers)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    zig-overlay = {
      url = "github:mitchellh/zig-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, flake-utils, zig-overlay }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        zig = zig-overlay.packages.${system}."0.16.0";

        # Fixed-output derivation that pre-fetches all Zig deps (e.g. xiph/flac
        # tarball via `b.dependency("flac", ...)`). This is the only step with
        # network access; the consumer derivation builds offline.
        # To recompute: set zigDepsHash = ""; run `nix build`; copy printed hash.
        zigDepsHash = "sha256-HYz5lvLqj+j29eDKWa6Q/ew7V5tNB72CRWnNakmQV98=";

        zigDeps = pkgs.stdenv.mkDerivation {
          pname = "flac-zig-deps";
          version = "0.1.0";
          src = ./.;
          nativeBuildInputs = [ zig pkgs.git pkgs.cacert ];
          outputHashMode = "recursive";
          outputHashAlgo = "sha256";
          outputHash = zigDepsHash;
          buildPhase = ''
            export HOME=$TMPDIR
            export ZIG_GLOBAL_CACHE_DIR=$out
            export SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt
            export GIT_SSL_CAINFO=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt
            zig build --fetch=all
          '';
          dontInstall = true;
          dontFixup = true;
        };
      in {
        packages.default = pkgs.stdenv.mkDerivation {
          pname = "flac";
          version = "0.1.0";
          src = ./.;
          nativeBuildInputs = [ zig pkgs.git pkgs.cacert ];
          dontConfigure = true;
          buildPhase = ''
            export HOME=$TMPDIR
            export ZIG_GLOBAL_CACHE_DIR=$TMPDIR/zig-cache
            mkdir -p "$ZIG_GLOBAL_CACHE_DIR"
            cp -r ${zigDeps}/* $ZIG_GLOBAL_CACHE_DIR/
            chmod -R u+w $ZIG_GLOBAL_CACHE_DIR
            zig build -Doptimize=ReleaseFast --prefix $out
          '';
          installPhase = "true";
        };

        devShells.default = pkgs.mkShell {
          buildInputs = [ zig pkgs.git ];
        };
      });
}
