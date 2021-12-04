{ wake-src, stdenv, pkgconfig, dash, fuse, gmp, ncurses, re2c, sqlite }:

stdenv.mkDerivation {
  pname = "wake";
  version = wake-src.shortRev;
  src = wake-src;

  nativeBuildInputs = [ pkgconfig re2c ];
  buildInputs = [ dash fuse gmp ncurses sqlite ];

  # install via wake?

  enableParallelBuilding = true;
}

