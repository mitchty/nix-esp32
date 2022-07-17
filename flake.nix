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
    in
    rec {
      packages = flake-utils.lib.flattenTree {
        llvm-xtensa = pkgs.callPackage ./packages/llvm-xtensa.nix { };
        esp-idf = pkgs.callPackage ./packages/esp-idf.nix { };
      };

      apps = {
        llvm-xtensa = flake-utils.lib.mkApp { drv = packages.llvm-xtensa; };
        esp-idf = flake-utils.lib.mkApp { drv = packages.esp-idf; };
      };

      # Basically same as devShell but makes it easier to nix run .#... to use
      # as a dev env in say nix-shell.
      defaultApp = flake-utils.lib.mkApp {
        drv = pkgs.stdenv.mkDerivation {
          name = "esp32-rs";

          buildInputs = [
            packages.llvm-xtensa
          ] ++ [
            pkgs.rust-bindgen
            pkgs.rust-analyzer
            pkgs.cargo-xbuild
            pkgs.openocd
          ];

          LIBCLANG_PATH = "${packages.llvm-xtensa}/lib";

          src = ./.;

          doCheck = false;

          installPhase = ''
            install -dm755 $out
          '';
        };
      };

      devShell = pkgs.mkShell {
        buildInputs = [
          pkgs.rust-bindgen
          pkgs.rust-analyzer
          pkgs.cargo-xbuild
          pkgs.openocd
        ] ++ [
          packages.llvm-xtensa
          packages.esp-idf
        ];
        LIBCLANG_PATH = "${packages.llvm-xtensa}/lib";
      };

      checks = {
        nixpkgs-fmt = pkgs.runCommand "check-nix-format" { } ''
          ${pkgs.nixpkgs-fmt}/bin/nixpkgs-fmt --check ${./.}
          install -dm755 $out
        '';
        # TODO: Build binutils as a cross compile chain and assemble the .S file
        # clang built to see if we're kosher.
        llvm-xtensa = pkgs.runCommand "check-llvm-xtensa" { } ''
          asmfile=$(${pkgs.coreutils}/bin/mktemp /tmp/XXXXXXXX-llvm-xtensa.S)
          cleanup() { rm -f $asmfile > /dev/null 2>&1; }
          trap cleanup EXIT
          ${packages.llvm-xtensa}/bin/clang -target xtensa -fomit-frame-pointer -S ${./checks/test.c} -o $asmfile
          install -dm755 $out
        '';
        # TODO: what to do here... to basic unit test...
        esp-idf = pkgs.runCommand "check-esp-idf" { } ''
          install -dm755 $out
        '';
        # TODO: rust..
        # rustc-xtensa = pkgs.runCommand "check-rustc-xtensa" { } ''
        #   ${rust-xtensa}/bin/rustc --version
        #   install -dm755 $out
        # '';
      };
    });
}
