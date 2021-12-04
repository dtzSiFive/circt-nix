{ wake-src, stdenv, pkgconfig, dash, fuse, gmp, ncurses, re2, sqlite }:

stdenv.mkDerivation {
  pname = "wake";
  version = wake-src.shortRev;
  src = wake-src;

  nativeBuildInputs = [ pkgconfig ];
  buildInputs = [ dash fuse gmp ncurses re2 sqlite ];

  # install via wake?

  enableParallelBuilding = true;
}

