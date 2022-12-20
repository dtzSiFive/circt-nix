{ lib, stdenv, cmake, fetchFromGitHub }:

stdenv.mkDerivation rec {
  pname = "espresso";
  version = "2.4";

  src = fetchFromGitHub {
    owner = "chipsalliance";
    repo = "espresso";
    rev = "v${version}";
    sha256 = "z5By57VbmIt4sgRgvECnLbZklnDDWUA6fyvWVyXUzsI=";
  };

  nativeBuildInputs = [ cmake ];

  meta = with lib; {
    description = "Tool to produce a minimal equivalent representation of a Boolean function";
    homepage = "https://github.com/chipsalliance/espresso";
    # Unknown.  Consider alternative.
    # license = [];
    maintainers = with maintainers; [ dtzWill ];
  };
}
