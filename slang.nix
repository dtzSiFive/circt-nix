{ lib, stdenv, slang-src, fetchFromGitHub
, cmake
, python3
, catch2_3
, mimalloc
}:

let
  getRev = src: src.shortRev or "dirty";
  mkVer = src:
    let
      date = builtins.substring 0 8 (src.lastModifiedDate or src.lastModified or "19700101");
    in
      "g${date}_${getRev src}";
  tag = "7.0";
  version = "${tag}${mkVer slang-src}";

  fmt_src = fetchFromGitHub {
    owner = "fmtlib";
    repo = "fmt";
    rev = "11.1.3";
    sha256 = "6r9D/csVSgS+T/H0J8cSR+YszxnH/h2V2odi2s6VYN8=";
  };
  # Drop for "catch2_3" once bump nixpkgs.
  catch2_3_pinned = catch2_3.overrideAttrs(o: 
    let version = "3.8.0"; in {
      src = fetchFromGitHub {
        owner = "catchorg";
        repo = "catch2";
        rev = "v${version}";
        sha256 = "2gK+CUpml6AaHcwNoq0tHLr2NwqtMPx+jP80/LLFFr4=";
      };
      inherit version;
  });
in stdenv.mkDerivation {
  pname = "slang";
  inherit version;
  nativeBuildInputs = [ cmake python3 ];
  buildInputs = [ python3 catch2_3_pinned mimalloc ];
  src = slang-src;

  patches = [
    ./patches/slang_git-don-t-fetch-fmt.patch
    ./patches/slang_git-pkgconfig.patch
  ];

  postPatch = ''
    ln -s ${fmt_src} external/fmt
    
    substituteInPlace source/util/VersionInfo.cpp.in \
      --subst-var SLANG_VERSION_MAJOR \
      --subst-var SLANG_VERSION_MINOR \
      --subst-var SLANG_VERSION_PATCH \
      --subst-var SLANG_VERSION_HASH
    substituteInPlace CMakeLists.txt \
      --replace-fail 'VERSION ''${SLANG_VERSION_STRING}' \
                     'VERSION "${tag}"'
  '';

  SLANG_VERSION_MAJOR = lib.versions.major tag;
  SLANG_VERSION_MINOR = lib.versions.minor tag;
  SLANG_VERSION_PATCH = 0; # patch isn't safe if no patch level :(
  SLANG_VERSION_HASH = getRev slang-src;

  doCheck = true;

  meta = with lib; {
    description = "SystemVerilog compiler and language services";
    homepage = "https://sv-lang.com";
    license = with licenses; [ mit ]; # (ASL2.0 w/LLVM Exception)
    maintainers = with maintainers; [ dtzWill ];
  };
}
