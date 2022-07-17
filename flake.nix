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

      inherit (pkgs) fetchFromGitHub;
      inherit (pkgs.stdenv) mkDerivation;

      # TODO: Why does calling this via callPackage no worky? Future me figure
      # out if you get a bug up your butt to do so this works for now so
      # whatever.
      llvm-xtensa = mkDerivation rec {
        name = "llvm-xtensa";
        version = "esp-14.0.0-20220415";

        target = "Xtensa";

        src = fetchFromGitHub {
          owner = "espressif";
          repo = "llvm-project";
          rev = "${version}";
          fetchSubmodules = true;
          leaveDotGit = true;
          sha256 = "sha256-FpUkLSSwCuojZev7+QWDD9KPYmpnxKqrJzNsLrVfkpQ=";
        };

        buildInputs = with pkgs; [
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

        # TODO: set this up a bit better, for now hacks is fine, builds at level 1 is sloooooow.
        CMAKE_BUILD_PARALLEL_LEVEL = "8";

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
    in
    rec {
      packages = flake-utils.lib.flattenTree {
        inherit llvm-xtensa;
        # TODO: figure out why callpackage no worky with fetchfromgithub like ^^^
        # llvm-xtensa = pkgs.callPackage ./packages/llvm-xtensa.nix { src = llvmsrc; };
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
        llvm-xtensa = pkgs.runCommand "check-llvm-xtensa" { } ''
          asmfile=$(${pkgs.coreutils}/bin/mktemp /tmp/llvm-xtensa.S-XXXXXXXXX)
          cleanup() { rm -f $asmfile > /dev/null 2>&1; }
          trap cleanup EXIT
          ${packages.llvm-xtensa}/bin/clang -target xtensa -fomit-frame-pointer -S ${./checks/test.c} -o $asmfile
          install -dm755 $out
        '';
        # TODO: what to do here...
        esp-idf = pkgs.runCommand "check-esp-idf" { } ''
          install -dm755 $out
        '';
        # rustc-xtensa = pkgs.runCommand "check-rustc-xtensa" { } ''
        #   ${rust-xtensa}/bin/rustc --version
        #   install -dm755 $out
        # '';
      };
    });
}

# Cargo/rust from the overlay used for bootstrapping/builds
# rust-xtensa = with pkgs; (makeRustPlatform {
#   cargo = rust-bin.stable.latest.minimal;
#   rustc = rust-bin.stable.latest.minimal;
# }).buildRustPackage rec {
#   pname = "rust-xtensa";
#   version = "0.3.7";

#   src = fetchFromGitHub {
#     owner = "blacknon";
#     repo = pname;
#     rev = version;
#     sha256 = "sha256-FVqvwqsHkV/yK5okL1p6TiNUGDK2ZnzVNO4UDVkG+zM=";
#     forceFetchGit = true;
#   };

#   # Update via regenpatches
#   cargoPatches = [
#     ./patches/hwatch-add-cargo-lock.patch
#   ];

#   cargoSha256 = "sha256-kfn7iOREFVS9LttfeRu+z5tXCheg54+tYozTsteFOX0=";

#   passthru.tests.version = testVersion { package = hwatch; };

#   latest = "curl --silent 'https://api.github.com/repos/blacknon/hwatch/releases/latest' | jq -r '.tag_name'";
# };
# rust-xtensa = with pkgs; rustc.overrideAttrs (old: rec {
# pname = "rustc-xtensa";

# Note not using fetchFromGitHub as the base derivation gets a tar.gz
# file and unpack phase and patch expect/are written to expect that.
# rust-src = fetchFromGitHub {
#   owner = "esp-rs";
#   repo = "rust";
#   rev = version;
#   sha256 = "sha256-g92H324NAO4LG05Gl0hNGLh+V7dKZw5oZOJHXtFpquE=";
#   fetchSubmodules = true;
# };

#     src = fetchurl {
#       url = "https://github.com/esp-rs/rust/archive/refs/heads/esp-1.61.0.0.tar.gz";
#       sha256 = "sha256-UZCBpMHSv000w+zze1KBPhtMz0lm8Lvfrs71ShD0FVM=";
#     };

#     cargo = rust-bin.stable.latest.minimal;
#     rustc = rust-bin.stable.latest.minimal;
#     version = "esp-1.61.0.0";
#     llvmSharedForBuild = llvm-xtensa;
#     llvmSharedForHost = llvm-xtensa;
#     llvmSharedForTarget = llvm-xtensa;
#     llvmShared = llvm-xtensa;

#     configureFlags =
#       (lib.lists.remove "--enable-llvm-link-shared" old.configureFlags
#         # (lib.lists.remove "--release-channel=stable" old.configureFlags)
#       ) ++ [
#         "--llvm-root=${llvm-xtensa}"
#         "--experimental-targets=Xtensa"
#         # "--release-channel=nightly"
#       ];

#     # postUnpack = ''
#     #   ${old.postUnpack}
#     # '';

#     # patchPhase = ''
#     #   set +x
#     #   ${old.p}
#     # '';

#     postConfigure = ''
#       ${old.postConfigure}
#       unpackFile "$cargoDeps"
#       mv $(stripHash $cargoDeps) vendor
#     '';

#     postInstall = ''
#       ${old.postInstall}
#       install -d $out/lib/rustlib/src
#       ln -s $src $out/lib/rustlib/src/rust
#       install -d $out/vendor
#       ln -s $src/library/rustc-std-workspace-alloc $out/vendor/rustc-std-workspace-alloc
#       ln -s $src/library/rustc-std-workspace-core $out/vendor/rustc-std-workspace-core
#       ln -s $src/library/rustc-std-workspace-std $out/vendor/rustc-std-workspace-std
#     '';
#   });
# in
# rec {
#   packages = flake-utils.lib.flattenTree {
#     inherit llvm-xtensa;
#     inherit esp-idf; # needed?
#     inherit rust-xtensa;
#   };
