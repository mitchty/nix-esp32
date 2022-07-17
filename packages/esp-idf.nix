{ lib
, stdenv
, pkgs
}: stdenv.mkDerivation rec {
  name = "esp-idf";
  oname = "espressif";

  python = pkgs.python3;

  src = pkgs.fetchFromGitHub {
    owner = oname;
    repo = name;
    rev = "v4.3.3";
    fetchSubmodules = true;
    sha256 = "sha256-IgWh2N8mCaiCsCyZ9jTizHgJoese/2hBjJq+TsV/ZWI=";
  };

  propagatedBuildInputs = with pkgs; [
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
}
