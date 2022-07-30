{ lib
, stdenv
, pkgs
, packages
}:
let

  # inherit (pkgs.rustPlatform) fetchCargoTarball;
  # fetchCargoTarball = pkgs.callPackage (pkgs.path + /pkgs/build-support/rust/fetch-cargo-tarball) { };
  # inherit (fetchCargoTarball) cargo-vendor-normalise;
  # inherit (pkgs.rustPlatform.fetchCargoTarball) cargo-vendor-normalise;
in
pkgs.rustc.overrideAttrs (old: rec {
  name = "rustc-xtensa";
  inherit src;
  cargoDeps = pkgs.rustPlatform.fetchCargoTarball {
    inherit src;
    sha256 = lib.fakeSha256;
  };
})
# pkgs.rustc.overrideAttrs (old: rec {
#   name = "rustc-xtensa";

#   inherit version src;
#   # inherit (old) postPatch nativeBuildInputs buildInputs;

#   cargoDeps = pkgs.rustPlatform.fetchCargoTarball {
#     src = "${src}";
#     sha256 = lib.fakeSha256;
#     nativeBuildInputs = [
#       pkgs.python3
#       pkgs.git
#       pkgs.cargo
#       #     cargo-vendor-normalise
#     ];
#   };

#   # cargoDeps = fetchCargoTarball {
#   #   inherit src;
#   #   sha256 = lib.fakeSha256;
#   #   nativeBuildInputs = [
#   #     pkgs.git
#   #     pkgs.python3
#   #     pkgs.cargo
#   #     cargo-vendor-normalise
#   #   ];
#   # };

#   llvmSharedForBuild = packages.llvm-xtensa;
#   llvmSharedForHost = packages.llvm-xtensa;
#   llvmSharedForTarget = packages.llvm-xtensa;
#   llvmShared = packages.llvm-xtensa;

#   configureFlags =
#     (lib.lists.remove "--enable-llvm-link-shared"
#       (lib.lists.remove "--release-channel=stable" old.configureFlags)) ++ [
#       "--llvm-root=${packages.llvm-xtensa}"
#       "--experimental-targets=Xtensa"
#       "--release-channel=nightly"
#     ];

#   # postConfigure = ''
#   #   ${old.postConfigure}
#   #   unpackFile "$cargoDeps"
#   #   mv $(stripHash $cargoDeps) vendor
#   # '';

#   postInstall = ''
#     ${old.postInstall}
#     mkdir -p $out/lib/rustlib/src
#     ln -s $src $out/lib/rustlib/src/rust
#     mkdir $out/vendor
#     ln -s $src/library/rustc-std-workspace-alloc $out/vendor/rustc-std-workspace-alloc
#     ln -s $src/library/rustc-std-workspace-core $out/vendor/rustc-std-workspace-core
#     ln -s $src/library/rustc-std-workspace-std $out/vendor/rustc-std-workspace-std
#   '';

#   # TODO: validate this all just quick hacks
#   meta = {
#     mainProgram = "rustc";
#     description = "rustc xtensa";
#     homepage = https://github.com/esp-rs/rust;
#     license = lib.licenses.asl20;
#   };
# })
