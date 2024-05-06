{ lib, stdenv, slang-src, fetchFromGitHub
, cmake
, python3
, catch2_3
}:

let
  getRev = src: src.shortRev or "dirty";
  mkVer = src:
    let
      date = builtins.substring 0 8 (src.lastModifiedDate or src.lastModified or "19700101");
    in
      "g${date}_${getRev src}";
  tag = "6.0";
  version = "${tag}${mkVer slang-src}";

  fmt_src = fetchFromGitHub {
    owner = "fmtlib";
    repo = "fmt";
    rev = "10.2.1";
    sha256 = "pEltGLAHLZ3xypD/Ur4dWPWJ9BGVXwqQyKcDWVmC3co=";
  };
  # Drop for "catch2_3" once bump nixpkgs.
  catch2_3_pinned = catch2_3.overrideAttrs(o: 
    let version = "3.5.4"; in {
      src = fetchFromGitHub {
        owner = "catchorg";
        repo = "catch2";
        rev = "v${version}";
        sha256 = "3z4/kBEW2zQQJkcdkXhN6NK9+wryXVfEm3MK1wZ3SCE=";
      };
      inherit version;
  });
in stdenv.mkDerivation {
  pname = "slang";
  inherit version;
  nativeBuildInputs = [ cmake python3 ];
  buildInputs = [ python3 catch2_3_pinned ];
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
      --replace 'VERSION ''${SLANG_VERSION_STRING}' \
                'VERSION "${tag}"'
  '';

  SLANG_VERSION_MAJOR = lib.versions.major tag;
  SLANG_VERSION_MINOR = lib.versions.minor tag;
  SLANG_VERSION_PATCH = 0; # patch isn't safe if no patch level :(
  SLANG_VERSION_HASH = getRev slang-src;

  # Disable mimalloc, adding as build input isn't enough (?).
  cmakeFlags = [ "-DSLANG_USE_MIMALLOC=OFF" ];

  # TODO: tests

  meta = with lib; {
    description = "SystemVerilog compiler and language services";
    homepage = "https://sv-lang.com";
    license = with licenses; [ mit ]; # (ASL2.0 w/LLVM Exception)
    maintainers = with maintainers; [ dtzWill ];
  };
}
