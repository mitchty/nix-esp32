{
  description = "Rust on esp32 toolchain";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-22.05";
    flake-utils.url = "github:numtide/flake-utils";
    rust.url = "github:oxalica/rust-overlay";
  };

  outputs = { nixpkgs, unstable, flake-utils, rust, ... }: flake-utils.lib.eachDefaultSystem (system:
    let
      pkgs = import nixpkgs {
        inherit system;
        overlays = [
          (import rust)
        ];
      };
      lib = pkgs.lib;
      name = "rustc-xtensa";
      version = "1.62.0.0";

      src = pkgs.fetchFromGitHub {
        owner = "esp-rs";
        repo = "rust";
        rev = "refs/heads/esp-${version}";
        fetchSubmodules = true;
        sha256 = "sha256-sqEHpCOrAnqIKdTFbdd1zk+yUWj3obNgACkAsQEGEBI=";
      };

      fetchCargoTarball = pkgs.callPackage (pkgs.path + /pkgs/build-support/rust/fetch-cargo-tarball) {
        inherit lib;
        stdenv = pkgs.stdenv;
        cacert = pkgs.cacert;
        python3 = pkgs.python3;
        git = pkgs.git;
        cargo = pkgs.cargo;
      };
    in
    rec {
      packages = flake-utils.lib.flattenTree {
        # Neither of these seem to work with the derivation seeing python when
        # it builds, macos or nixos 22.05 for that matter.
        #
        # I get...
        # [1/0/1 built] building rustc-xtensa-vendor.tar.gz (configurePhase): ./configure: exec: line 18: python: not found
        # yet...
        # https://github.com/NixOS/nixpkgs/blob/master/pkgs/build-support/rust/fetch-cargo-tarball/default.nix#L36
        # has
        #   nativeBuildInputs = [ cacert git cargo-vendor-normalise cargo ] ++ nativeBuildInputs;
        # Should all be good right? seemingly? I guess but not enitirely sure
        # how to yoink in cargo-vendor-normalise as well as a dep as while this
        # does get us to a mostly ok buildPhase it fails with this up top but
        # does at least invoke cargo to vendor stuff at least, still every usage
        # of fetchCargoTarball doesn't involve this level of shenanigans:
        #
        # @nix { "action": "setPhase", "phase": "buildPhase" }                                                                  building
        # /nix/store/w4yyp4pm2czqhr0078c0wwlx2dk2dzqw-stdenv-linux/setup: line 1397: cargo-vendor-normalise: command not found  warning: profiles for the non root package will be ignored, specify profiles at the workspace root:
        # package:   /build/source/src/tools/rls/racer/Cargo.toml                                                               workspace: /build/source/Cargo.toml
        cargotarball = fetchCargoTarball {
          inherit src name;
          sha256 = pkgs.lib.fakeSha256;
        };
        cargotarballdrv = pkgs.rustPlatform.fetchCargoTarball {
          inherit src name;
          sha256 = pkgs.lib.fakeSha256;
        };

        # Note: this *DOES* work around it but why in the world should I need to
        # pass in duplicates for nativeBuildInputs already defined?
        cargotarballdrvwithinputs = pkgs.rustPlatform.fetchCargoTarball {
          inherit src name;
          sha256 = pkgs.lib.fakeSha256;
          nativeBuildInputs = with pkgs; [ cacert cargo git python3 ];
        };
        default = pkgs.stdenv.mkDerivation {
          name = "esp32-rs";

          buildInputs = [
            packages.cargotarball
            packages.cargotarballdrv
            packages.cargotarballdrvwithinputs
          ] ++ [
            pkgs.rust-bindgen
            pkgs.rust-analyzer
            pkgs.cargo-xbuild
            pkgs.openocd
          ];

          src = ./.;

          doCheck = false;

          installPhase = ''
            install -dm755 $out
          '';
        };
      };

      apps = {
        cargotarball = flake-utils.lib.mkApp { drv = packages.cargotarball; };
        cargotarballdrv = flake-utils.lib.mkApp { drv = packages.cargotarballdrv; };
        cargotarballdrvwithinputs = flake-utils.lib.mkApp { drv = packages.cargotarballdrvwithinputs; };
      };

      # Basically same as devShell but makes it easier to nix run .#... to use
      # as a dev env in say nix-shell.
      defaultApp = flake-utils.lib.mkApp {
        drv = packages.default;
      };

      devShell = pkgs.mkShell {
        buildInputs = [
          packages.cargotarball
          packages.cargotarballdrv
          packages.cargotarballdrvwithinputs
        ] ++ [
          pkgs.rust-bindgen
          pkgs.rust-analyzer
          pkgs.cargo-xbuild
          pkgs.openocd
        ];
      };

      checks = {
        nixpkgs-fmt = pkgs.runCommand "check-nix-format" { } ''
          ${pkgs.nixpkgs-fmt}/bin/nixpkgs-fmt --check ${./.}
          install -dm755 $out
        '';
      };
    });
}
