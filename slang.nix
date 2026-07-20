{
  lib,
  stdenv,
  slang-src,
  fetchFromGitHub,
  fetchpatch,
  cmake,
  python3,
  catch2_3,
  mimalloc,
  tomlplusplus,
  enableMimalloc ? false,
  # MUST match circt.nix's enableAssertions. CIRCT's
  # cmake/modules/SlangCompilerOptions.cmake defines SLANG_ASSERT_ENABLED=1 for
  # every CIRCT TU that includes slang headers whenever LLVM_ENABLE_ASSERTIONS
  # is on, but slang does not export that macro from its installed target. The
  # macro changes slang's class layout (e.g. BumpAllocator gains a `frozen`
  # member), so a slang built without it silently ABI-mismatches an
  # assertions-enabled CIRCT and segfaults at runtime inside
  # slang::SourceManager::assignBuffer.
  enableAssertions ? true,
  # slang's own CLI gates its -j/--threads option on SLANG_USE_THREADS
  # (source/driver/Driver.cpp: without it numThreads is pinned to 1), so leave
  # threads on for the standalone package. CIRCT overrides this to false --
  # see flake.nix -- to match how it configures slang when building it from
  # source, where it disables threads to dodge a race in BS::thread_pool.
  # Unlike SLANG_ASSERT_ENABLED this macro *is* exported to consumers, so
  # either setting is ABI-consistent; it only needs to match CIRCT's intent.
  enableThreads ? true,
}:

let
  getRev = src: src.shortRev or "dirty";
  mkVer =
    src:
    let
      date = builtins.substring 0 8 (src.lastModifiedDate or src.lastModified or "19700101");
    in
    "g${date}_${getRev src}";
  tag = "11.0";
  version = "${tag}${mkVer slang-src}";

  fmt_src = fetchFromGitHub {
    owner = "fmtlib";
    repo = "fmt";
    tag = "12.1.0";
    hash = "sha256-ZmI1Dv0ZabPlxa02OpERI47jp7zFfjpeWCy1WyuPYZ0=";
  };
  # slang >=11.0 uses boost::regex as a header-only lib. Without a system
  # boost it FetchContent's just the regex repo, which the sandbox can't do,
  # so pre-fetch it and point FetchContent at it (see cmakeFlags below).
  # Deliberately not satisfied with nixpkgs' full boost: CIRCT builds slang
  # without exception support, which needs slang's vendored boost headers
  # (cf. llvm/circt#10689).
  boost_regex_src = fetchFromGitHub {
    owner = "MikePopoloski";
    repo = "regex";
    tag = "boost-1.91.0";
    hash = "sha256-/a3wW6hMQwxrxs7pX3KKZGKFTm78HALaquBAwDMJfq4=";
  };
  # slang >=11.0 wants Catch2 >=3.15 (FIND_PACKAGE_ARGS 3.15); nixpkgs is
  # still on 3.14.0, so pin to the version slang itself FetchContent-pins.
  # Drop this once nixpkgs' catch2_3 catches up.
  catch2_3_pinned = catch2_3.overrideAttrs (
    o:
    let
      version = "3.15.1";
    in
    {
      src = fetchFromGitHub {
        owner = "catchorg";
        repo = "catch2";
        tag = "v${version}";
        hash = "sha256-JSMAlIDanPLzxhvFXeF3T5NQkj8Gye+bT92OjZS+XOs=";
      };
      inherit version;
    }
  );
in
stdenv.mkDerivation {
  pname = "slang";
  inherit version;
  nativeBuildInputs = [
    cmake
    python3
  ]
  ++ lib.optional enableMimalloc mimalloc;
  buildInputs = [
    python3
    catch2_3_pinned
  ];

  # slang >=11.0 pulls in toml++, satisfied via its FIND_PACKAGE_ARGS 3.4 so
  # FetchContent doesn't reach the network. Since it's found as a system
  # package, slang's generated slangConfig.cmake emits
  # find_dependency(tomlplusplus), so consumers (CIRCT) need it at configure
  # time too -- propagate rather than making each consumer list it.
  propagatedBuildInputs = [ tomlplusplus ];
  src = slang-src;

  # slang-vendored-boost-headers.patch dropped for 11.0: upstream's *Map.h now
  # selects the vendored single-header boost via __has_include, which already
  # picks the vendored copy when no system boost is present (as here).
  patches = [
    ./patches/slang-don-t-fetch-fmt.patch
    ./patches/slang-pkgconfig.patch
    ./patches/slang-install-bs-thread-pool.patch
  ];

  # Builds w/mimalloc if have right version, disable for now.
  cmakeFlags = [
    "-DSLANG_USE_MIMALLOC=${if enableMimalloc then "ON" else "OFF"}"
    # Use the pre-fetched boost::regex instead of letting FetchContent clone it.
    "-DFETCHCONTENT_SOURCE_DIR_BOOST_REGEX=${boost_regex_src}"
    "-DSLANG_USE_THREADS=${if enableThreads then "ON" else "OFF"}"
  ];

  # Not a cmakeFlag: slang only defines this itself for debug/fuzz builds, and
  # never exports it. See the enableAssertions comment above.
  env.NIX_CFLAGS_COMPILE = lib.optionalString enableAssertions "-DSLANG_ASSERT_ENABLED=1";

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

  # Consumers must build with a matching setting; circt.nix asserts on this.
  passthru = { inherit enableAssertions; };

  meta = with lib; {
    description = "SystemVerilog compiler and language services";
    homepage = "https://sv-lang.com";
    license = with licenses; [ mit ]; # (ASL2.0 w/LLVM Exception)
    maintainers = with maintainers; [ dtzWill ];
  };
}
