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
      in {
        # NOTE: build.zig pulls libFLAC sources via `b.dependency("flac", ...)`
        # which `zig fetch`es a tarball from xiph/flac. The Nix sandbox blocks
        # network access — a fully-sandboxed Nix build will need a fixed-output
        # `zigDeps` derivation (see CLAUDE.md fix-zig-deps-hash pattern).
        # For now this flake works in `dev-shell`; full sandboxed `nix build`
        # is a follow-up.
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
            zig build -Doptimize=ReleaseFast --prefix $out
          '';
          installPhase = "true";
        };

        devShells.default = pkgs.mkShell {
          buildInputs = [ zig pkgs.git ];
        };
      });
}
