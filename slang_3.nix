{ lib, stdenv, fetchFromGitHub
, cmake
, python3
, catch2_3
}:

let
  tag = "3.0";

  fmt_src = fetchFromGitHub {
    owner = "fmtlib";
    repo = "fmt";
    rev = "9.1.0";
    sha256 = "rP6ymyRc7LnKxUXwPpzhHOQvpJkpnRFOt2ctvUNlYI0=";
  };
  # 2.0.0 maybe, but this seems to work too.
  unordered_dense_src = fetchFromGitHub {
    owner = "martinus";
    repo = "unordered_dense";
    rev = "v3.1.1";
    sha256 = "7tx7s2j/UjsAjo47isQfqD+U2U6TAcMgG9VXJz4GDWQ=";
  };
in stdenv.mkDerivation {
  pname = "slang";
  version = "v${tag}";
  nativeBuildInputs = [ cmake python3 ];
  buildInputs = [ python3 catch2_3 ];
  src = fetchFromGitHub {
    owner = "MikePopoloski";
    repo = "slang";
    rev = "v${tag}";
    sha256 = "v2sStvukLFMRXGeATxvizmnwEPDE4kwnS06n+37OrJA=";
  };

  patches = [
    ./patches/slang_3-pkgconfig.patch
    ./patches/slang_3-don-t-fetch-fmt-unordered_dense.patch
    ./patches/slang_3-Drop-span.hpp-from-install-was-removed-in-f663d45cb9.patch
  ];

  postPatch = ''
    ln -s ${fmt_src} external/fmt
    ln -s ${unordered_dense_src} external/unordered_dense
    
    substituteInPlace source/util/Version.cpp.in \
      --subst-var SLANG_VERSION_MAJOR \
      --subst-var SLANG_VERSION_MINOR \
      --subst-var SLANG_VERSION_PATCH \
      --subst-var SLANG_VERSION_HASH
    substituteInPlace CMakeLists.txt \
      --replace 'VERSION ''${SLANG_VERSION_STRING}' \
                'VERSION "${tag}"'
  '';

  SLANG_VERSION_MAJOR = lib.versions.major tag;
  SLANG_VERSION_MINOR = lib.versions.minor tag;
  SLANG_VERSION_PATCH = 0; # patch isn't safe if no patch level :(
  SLANG_VERSION_HASH = "";

  # TODO: tests

  meta = with lib; {
    description = "SystemVerilog compiler and language services";
    homepage = "https://sv-lang.com";
    license = with licenses; [ mit ]; # (ASL2.0 w/LLVM Exception)
    maintainers = with maintainers; [ dtzWill ];
  };
}
