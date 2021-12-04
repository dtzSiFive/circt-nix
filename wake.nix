{ wake-src, stdenv, pkgconfig, git, dash, fuse, gmp, ncurses, re2c, re2, sqlite }:

stdenv.mkDerivation {
  pname = "wake";
  version = wake-src.shortRev;
  src = wake-src;

  nativeBuildInputs = [ pkgconfig re2c git ];
  buildInputs = [ dash fuse gmp ncurses re2 sqlite ];

  # install via wake?

  enableParallelBuilding = true;
}

