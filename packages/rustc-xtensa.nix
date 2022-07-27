{ lib
, stdenv
, pkgs
, packages
}:
let
  rust = rec {
    version = "1.62.0.0";

    src = pkgs.fetchFromGitHub {
      owner = "esp-rs";
      repo = "rust";
      rev = "refs/heads/esp-${version}";
      fetchSubmodules = true;
      sha256 = "sha256-sqEHpCOrAnqIKdTFbdd1zk+yUWj3obNgACkAsQEGEBI=";
    };

    cargoDeps = pkgs.rustPlatform.fetchCargoTarball {
      inherit src;
      sha256 = lib.fakeSha256;
    };
  };
in
pkgs.rustc.overrideAttrs (old: rec {
  name = "rustc-xtensa";
  inherit (rust) version src cargoDeps;
  inherit (old) postPatch nativeBuildInputs buildInputs;

  # buildInputs = [
  #   pkgs.python
  #   pkgs.rustPlatform.cargoSetupHook
  # ];

  llvmSharedForBuild = packages.llvm-xtensa;
  llvmSharedForHost = packages.llvm-xtensa;
  llvmSharedForTarget = packages.llvm-xtensa;
  llvmShared = packages.llvm-xtensa;

  configureFlags =
    (lib.lists.remove "--enable-llvm-link-shared"
      (lib.lists.remove "--release-channel=stable" old.configureFlags)) ++ [
      "--llvm-root=${packages.llvm-xtensa}"
      "--experimental-targets=Xtensa"
      "--release-channel=nightly"
    ];

  # TODO: validate this all just quick hacks
  meta = {
    mainProgram = "rustc";
    description = "rustc xtensa";
    homepage = https://github.com/esp-rs/rust;
    license = lib.licenses.asl20;
  };
})
