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
      stable = nixpkgs.legacyPackages.${system};

      fake = nixpkgs.legacyPackages.${system}.lib.fakeSha256;

      # Silly wrapper around fetchurl
      extra = fname: sha256: from: pkgs.fetchurl rec {
        url = "${from}";
        name = "${fname}";
        inherit sha256;
      };

      # Thing is a beast to build/update...
      llvm-xtensa = with pkgs; stdenv.mkDerivation rec {
        name = "llvm-xtensa";
        version = "esp-14.0.0-20220415";

        target = "Xtensa";

        src = fetchFromGitHub {
          owner = "espressif";
          repo = "llvm-project";
          rev = "${version}";
          fetchSubmodules = true;
          leaveDotGit = true;
          sha256 = "sha256-goXiXDyY2D0WtdwMPV/5Y37MtGUN+yIOGMuS+0TFic8=";
        };

        buildInputs = [
          clang
          git
          python3
          cmake
          ninja
          llvm
        ];

        phases = [
          "unpackPhase"
          "buildPhase"
          "installPhase"
          "fixupPhase"
        ];

        # http://quickhack.net/nom/blog/2019-05-14-build-rust-environment-for-esp32.html
        buildPhase = ''
          install -d build
          cd build

          cmake -S ../llvm -D LLVM_ENABLE_PROJECTS="clang;libcxx;libcxxabi" -D LLVM_BUILD_LLVM_DYLIB= -D LLVM_EXPERIMENTAL_TARGETS_TO_BUILD=${target} -D LLVM_TARGETS_TO_BUILD=${target} -D CMAKE_BUILD_TYPE=Release

          cmake --build .
        '';

        installPhase = ''
          mkdir -p $out
          cmake -DCMAKE_INSTALL_PREFIX=$out -P cmake_install.cmake
        '';

        meta.mainProgram = "clang";
      };

      esp-idf = with pkgs; stdenv.mkDerivation rec {
        name = "esp-idf";
        oname = "espressif";

        inherit python;

        src = fetchFromGitHub {
          owner = oname;
          repo = name;
          rev = "v4.3.3";
          fetchSubmodules = true;
          sha256 = "sha256-IgWh2N8mCaiCsCyZ9jTizHgJoese/2hBjJq+TsV/ZWI=";
        };

        propagatedBuildInputs = [
          cmake
          ninja
          gcc
          git
          ncurses
          flex
          bison
          gperf
          ccache
          python3
        ];

        phases = [ "unpackPhase" "installPhase" "fixupPhase" ];

        installPhase = ''
          cp -r . $out
        '';
      };
    in
    rec {
      packages = flake-utils.lib.flattenTree {
        inherit llvm-xtensa;
        inherit esp-idf; # needed?
      };

      defaultApp = flake-utils.lib.mkApp {
        drv = llvm-xtensa;
      };

      devShell = with pkgs; mkShell {
        buildInputs = [
          # Stuff I don't need to repackage
          rust-bindgen
          rust-analyzer
          cargo-xbuild
          openocd
        ] ++ [
          llvm-xtensa
          esp-idf
        ];
      };

      checks.nixpkgs-fmt = pkgs.runCommand "check-nix-format" { } ''
        ${pkgs.nixpkgs-fmt}/bin/nixpkgs-fmt --check ${./.}
        mkdir $out #sucess
      '';

      checks.llvm-xtensa = pkgs.runCommand "check-llvm-xtensa" { } ''
        set -x
        ${llvm-xtensa}/bin/clang -target xtensa -fomit-frame-pointer -S ${./checks/test.c} -o /dev/null
        mkdir $out #sucess
      '';
    }
  );
}
