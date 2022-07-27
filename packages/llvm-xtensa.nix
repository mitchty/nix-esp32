{ lib
, stdenv
, pkgs
, src
}:

stdenv.mkDerivation rec {
  name = "llvm-xtensa";
  version = "esp-14.0.0-20220415";

  target = "Xtensa";

  src = pkgs.fetchFromGitHub {
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

  # http://quickhack.net/nom/blog/2019-05-14-build-rust-environment-for-esp32.html
  buildPhase = ''
    install -d build
    cd build

    cmake -S ../llvm -D LLVM_ENABLE_PROJECTS="clang;libcxx;libcxxabi" -D LLVM_BUILD_LLVM_DYLIB= -D LLVM_EXPERIMENTAL_TARGETS_TO_BUILD=${target} -D LLVM_TARGETS_TO_BUILD=${target} -D CMAKE_BUILD_TYPE=Release

    export CMAKE_BUILD_PARALLEL_LEVEL=$NIX_BUILD_CORES
    cmake --build .
  '';

  installPhase = ''
    mkdir -p $out
    cmake -DCMAKE_INSTALL_PREFIX=$out -P cmake_install.cmake
  '';

  meta = {
    mainProgram = "clang";
    description = "LLVM xtensa";
    homepage = https://github.com/espressif/llvm-project;
    license = lib.licenses.asl20;
  };
}
