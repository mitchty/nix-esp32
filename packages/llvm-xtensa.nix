{ lib
, stdenv
, pkgs
, src
}:

stdenv.mkDerivation rec {
  name = "llvm-xtensa";
  version = "14.0.0";

  inherit src;

  # src = pkgs.fetchFromGitHub {
  #   owner = "espressif";
  #   repo = "llvm-project";
  #   #   # rev = "esp-14.0.0-20220415";
  #   #   # sha256 = "sha256-FpUkLSSwCuojZev7+QWDD9KPYmpnxKqrJzNsLrVfkpQ=";
  #   rev = "xtensa_release_14.0.0";
  #   sha256 = lib.fakeSha256;
  #   #   rev = "esp-14.0.0-20220415";
  #   #   sha256 = "sha256-d83JWsj6snhSf5wpJ5/8NYep8C8+SLOvI9jynEPWiCo=";
  #   fetchSubmodules = true;
  #   #   leaveDotGit = true;
  # };

  # buildInputs = lib.attrVals [
  #   "python3"
  #   "cmake"
  #   "ninja"
  # ]
  #   pkgs;
  buildInputs = with pkgs; [
    git
    python3
    cmake
    ninja
  ];

  sourceRoot = "source/llvm";

  target = "Xtensa";
  cmakeFlags = [
    "-DLLVM_ENABLE_PROJECTS=clang"
    "-DLLVM_BUILD_DYLIB="
    "-DLLVM_INSTALL_UTILS=ON"
    "-DLLVM_EXPERIMENTAL_TARGETS_TO_BUILD=${target}"
    "-DLLVM_TARGETS_TO_BUILD=${target}"
    "-DLLVM_ENABLE_RUNTIMES=libcxx"
    "-DCMAKE_BUILD_TYPE=Release"
  ];

  meta = {
    mainProgram = "clang";
    description = "LLVM xtensa";
    homepage = https://github.com/espressif/llvm-project;
    license = lib.licenses.asl20;
  };

  # passthru.tests.version = stdenv.testVersion { package = llvm-xtensa; };
}
# stdenv.mkDerivation rec {
#         name = "llvm-xtensa";
#         version = "";

#         target = "Xtensa";

#         };

#         buildInputs = [
#           clang
#           git
#           python3
#           cmake
#           ninja
#           llvm
#         ];

#         phases = [
#           "unpackPhase"
#           "buildPhase"
#           "installPhase"
#           "fixupPhase"
#         ];

#         # http://quickhack.net/nom/blog/2019-05-14-build-rust-environment-for-esp32.html
#         buildPhase = ''
#           install -d build
#           cd build

#           cmake -S ../llvm -D LLVM_ENABLE_PROJECTS="clang;libcxx;libcxxabi" -D LLVM_BUILD_LLVM_DYLIB= -D  -D LLVM_TARGETS_TO_BUILD=${target} -D CMAKE_BUILD_TYPE=Release

#           cmake --build .
#         '';

#         installPhase = ''
#           mkdir -p $out
#           cmake -DCMAKE_INSTALL_PREFIX=$out -P cmake_install.cmake
#         '';

#         meta.mainProgram = "clang";
#       };
