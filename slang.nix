{ lib, stdenv, slang-src
, fetchFromGitHub, fetchpatch
, cmake
, python3
, catch2_3
, mimalloc
, enableMimalloc ? false
}:

let
  getRev = src: src.shortRev or "dirty";
  mkVer = src:
    let
      date = builtins.substring 0 8 (src.lastModifiedDate or src.lastModified or "19700101");
    in
      "g${date}_${getRev src}";
  tag = "9.0";
  version = "${tag}${mkVer slang-src}";

  fmt_src = fetchFromGitHub {
    owner = "fmtlib";
    repo = "fmt";
    rev = "11.2.0";
    hash = "sha256-sAlU5L/olxQUYcv8euVYWTTB8TrVeQgXLHtXy8IMEnU=";
  };
  # Drop for "catch2_3" once bump nixpkgs.
  catch2_3_pinned = catch2_3.overrideAttrs(o: 
    let version = "3.9.0"; in {
      src = fetchFromGitHub {
        owner = "catchorg";
        repo = "catch2";
        rev = "v${version}";
        hash = "sha256-3jdgpHk2nxCK27DffoiG/D7oDdnm7jxlcejauDgshDA=";
      };
      inherit version;
      patches = o.patches or [] ++ [
        (fetchpatch {
           url = "https://github.com/catchorg/Catch2/commit/3839e27f056cd975e5be2faa9adb5a8cf1f5dcf4.patch";
           hash = "sha256-C0A5VoDzf/TsIZId6u54FHcCtdTONe2PLQr0eBjXDmI=";
           revert = true;
        })
      ];
  });
in stdenv.mkDerivation {
  pname = "slang";
  inherit version;
  nativeBuildInputs = [ cmake python3 ] ++ lib.optional enableMimalloc mimalloc;
  buildInputs = [ python3 catch2_3_pinned ];
  src = slang-src;

  patches = [
    ./patches/slang_git-don-t-fetch-fmt.patch
    ./patches/slang_git-pkgconfig.patch
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
