{ lib, stdenv, fetchFromGitHub
, cmake
, python3
, catch2_3
, mimalloc
, enableMimalloc ? false
}:

let
  version = "9.1";
  tag = "v${version}";

  fmt_src = fetchFromGitHub {
    owner = "fmtlib";
    repo = "fmt";
    tag = "11.2.0";
    hash = "sha256-sAlU5L/olxQUYcv8euVYWTTB8TrVeQgXLHtXy8IMEnU=";
  };
  # Drop for "catch2_3" once bump nixpkgs.
  catch2_3_pinned = catch2_3.overrideAttrs(o: 
    let version = "3.10.0"; in {
      src = fetchFromGitHub {
        owner = "catchorg";
        repo = "catch2";
        tag = "v${version}";
        hash = "sha256-eeqqzHMeXLRiXzbY+ay8gJ/YDuxDj3f6+d6eXA1uZHE=";
      };
      inherit version;
      postPatch = o.postPatch or "" + ''
        substituteInPlace CMake/*.pc.in \
          --replace-fail "\''${prefix}/" ""
      '';
  });
in stdenv.mkDerivation {
  pname = "slang";
  inherit version;
  nativeBuildInputs = [ cmake python3 ] ++ lib.optional enableMimalloc mimalloc;
  buildInputs = [ python3 catch2_3_pinned ];

  src = fetchFromGitHub {
    owner = "MikePopoloski";
    repo = "slang";
    rev = tag;
    hash = "sha256-IfRh6F6vA+nFa+diPKD2aMv9kRbvVIY80IqX0d+d5JA=";
  };

  patches = [
    ./patches/slang_git-don-t-fetch-fmt.patch
    ./patches/slang_git-pkgconfig.patch
    ./patches/slang_git-vendored-boost-headers.patch
  ];

  # Builds w/mimalloc if have right version, disable for now.
  cmakeFlags = [ "-DSLANG_USE_MIMALLOC=${if enableMimalloc then "ON" else "OFF"}" ];

  postPatch = ''
    ln -s ${fmt_src} external/fmt
    
    substituteInPlace source/util/VersionInfo.cpp.in \
      --subst-var SLANG_VERSION_MAJOR \
      --subst-var SLANG_VERSION_MINOR \
      --subst-var SLANG_VERSION_PATCH \
      --subst-var SLANG_VERSION_HASH
    substituteInPlace CMakeLists.txt \
      --replace-fail 'VERSION ''${SLANG_VERSION_STRING}' \
                     'VERSION "${version}"'
  '';

  SLANG_VERSION_MAJOR = lib.versions.major version;
  SLANG_VERSION_MINOR = lib.versions.minor version;
  SLANG_VERSION_PATCH = 0; # patch isn't safe if no patch level :(
  SLANG_VERSION_HASH = "";

  doCheck = true;

  meta = with lib; {
    description = "SystemVerilog compiler and language services";
    homepage = "https://sv-lang.com";
    license = with licenses; [ mit ]; # (ASL2.0 w/LLVM Exception)
    maintainers = with maintainers; [ dtzWill ];
  };
}
