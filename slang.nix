{ lib, stdenv, slang-src
, cmake, ninja
, python3
, fetchFromGitHub }:
let
  getRev = src: src.shortRev or "dirty";
  mkVer = src:
    let
      date = builtins.substring 0 8 (src.lastModifiedDate or src.lastModified or "19700101");
    in
      "g${date}_${getRev src}";
  tag = "1.0";
  version = "${tag}${mkVer slang-src}";

  fmt_src = fetchFromGitHub {
    owner = "fmtlib";
    repo = "fmt";
    rev = "9.0.0";
    sha256 = "nwlAzMkY1JdhLtes48VaNH9LS7GzqtPCwk2dZA/bGmQ=";
  };
  unordered_dense_src = fetchFromGitHub {
    owner = "martinus";
    repo = "unordered_dense";
    rev = "v1.3.2";
    sha256 = "AT90sXousdes+zqixWy69gbrV9jqB7789/33ENm5/a4=";
  };
  catch2_src = fetchFromGitHub {
    owner = "catchorg";
    repo = "catch2";
    rev = "v3.1.0";
    sha256 = "bp/KLTr754txVUTAauJFrsxGKgZicUEe40CZBDkxRwk=";
  };
in stdenv.mkDerivation {
  pname = "slang";
  inherit version;
  nativeBuildInputs = [ cmake python3 ninja ];
  src = slang-src;

  patches = [
    ./patches/slang-dont-fetch.patch
    ./patches/slang-ext-rel-to-source.patch
  ];

  postPatch = ''
    ln -s ${fmt_src} external/fmt
    ln -s ${unordered_dense_src} external/unordered_dense
    ln -s ${catch2_src} external/catch2
    
    substituteInPlace source/util/Version.cpp.in \
      --subst-var SLANG_VERSION_MAJOR \
      --subst-var SLANG_VERSION_MINOR \
      --subst-var SLANG_VERSION_PATCH \
      --subst-var SLANG_VERSION_HASH
    substituteInPlace CMakeLists.txt --replace "''${SLANG_VERSION_STRING}" "${tag}"
  '';

    SLANG_VERSION_MAJOR = lib.versions.major tag;
    SLANG_VERSION_MINOR = lib.versions.minor tag;
    SLANG_VERSION_PATCH = 0; # patch isn't safe if no patch level :(
    SLANG_VERSION_HASH = getRev slang-src;

  meta = with lib; {
    description = "SystemVerilog compiler and language services";
    homepage = "https://sv-lang.com";
    license = with licenses; [ mit ]; # (ASL2.0 w/LLVM Exception)
    maintainers = with maintainers; [ dtzWill ];
  };
}
