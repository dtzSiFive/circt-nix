{
  lib,
  fetchpatch,
  stdenv,
  cmake,
  pkg-config,
  gnugrep,
  coreutils,
  libllvm,
  mlir,
  lit,
  circtSrc,
  version,
  grpc,
  verilator,
  # TODO: Shouldn't need to specify these deps, fix in upstream nixpkgs!
  or-tools,
  bzip2,
  cbc,
  eigen,
  glpk,
  re2,
  python3,
  llvm-third-party-src,
  ninja,
  doxygen,
  graphviz-nox,
  enableDocs ? false,
  enableAssertions ? true,
  enableOrTools ? false, # stdenv.hostPlatform.isLinux
  slang,
  enableSlang ? true,
  enableLLHD ? false, # Drops llhd-sim -> lib output dep.
  withVerilator ? !stdenv.hostPlatform.isDarwin && stdenv.buildPlatform == stdenv.hostPlatform,
  z3,
  buildSharedLibs ? libllvm.buildSharedLibs or false,
}:

# slang's ABI depends on SLANG_ASSERT_ENABLED, which CIRCT's
# cmake/modules/SlangCompilerOptions.cmake derives from LLVM_ENABLE_ASSERTIONS
# but slang does not export. A mismatch builds and links cleanly, then
# segfaults at runtime in slang::SourceManager::assignBuffer -- catch it here
# instead. See slang.nix's enableAssertions.
assert enableSlang -> slang.enableAssertions == enableAssertions;

# TODO: or-tools, needs cmake bits maybe?
stdenv.mkDerivation {
  pname = "circt";
  inherit version;
  nativeBuildInputs = [
    cmake
    python3
    ninja
    pkg-config
  ]
  ++ lib.optionals enableDocs [
    doxygen
    graphviz-nox
  ];
  buildInputs = [
    mlir
    libllvm
    grpc
    z3
  ]
  ++ lib.optionals enableOrTools [
    or-tools
    bzip2
    cbc
    eigen
    glpk
    re2
  ]
  ++ lib.optional enableSlang slang
  ++ lib.optional withVerilator verilator;
  # circtSrc already includes the llvm submodule content (see flake.nix).
  src = circtSrc;

  patches = [
    ./patches/circt-mlir-tblgen-path.patch
    ./patches/circt-mlir-runner-target.patch
    ./patches/circt-install-dir.patch
    ./patches/circt-lit-dylib-paths.patch
  ];
  postPatch = ''
    substituteInPlace cmake/modules/GenVersionFile.cmake \
      --replace-fail '"unknown git version"' '"firtool-${version}"'

    find test -type f -exec \
      sed -i -e 's,--test /usr/bin/env,--test ${lib.getBin coreutils}/bin/env,' \{\} \;
  ''
  # CIRCT refers to slang's library as `slang_slang` (the target name it gets
  # when built from source via FetchContent); an installed slang exports it as
  # `slang::slang` instead. Rewrite every consumer rather than an enumerated
  # list -- releases keep adding new ones, and a missed file only shows up as a
  # late `cannot find -lslang_slang` link error (1.152.0 added the ImportVerilog
  # unittest). Deliberately scoped to lib/ and unittests/: the top-level
  # CMakeLists.txt also says `slang_slang`, but there it is the real target,
  # inside the CIRCT_SLANG_BUILD_FROM_SOURCE branch we keep disabled.
  + lib.optionalString enableSlang ''
    # `|| true`: grep exits 1 on no matches, which would otherwise abort the
    # builder (set -e) before the clearer message below.
    slangConsumers=$(grep -rl slang_slang lib unittests --include=CMakeLists.txt || true)
    if [ -z "$slangConsumers" ]; then
      echo "postPatch: no slang_slang references found under lib/ or unittests/;" \
           "has CIRCT switched to slang::slang upstream?" >&2
      exit 1
    fi
    for f in $slangConsumers; do
      substituteInPlace "$f" --replace-fail slang_slang slang::slang
    done
  '';

  outputs = [
    "out"
    "lib"
    "dev"
  ];

  cmakeFlags = [
    "-DLLVM_EXTERNAL_LIT=${lit}/bin/.lit-wrapped" # eep
    "-DLLVM_LIT_ARGS=-v"
    "-DLLVM_THIRD_PARTY_DIR=${llvm-third-party-src}"
    "-DCIRCT_INSTALL_PACKAGE_DIR==${placeholder "dev"}/lib/cmake/circt"
    "-DCIRCT_TOOLS_INSTALL_DIR=${placeholder "out"}/bin"
    "-DCIRCT_LIBRARY_DIR=${placeholder "lib"}/lib"
    "-DCIRCT_LLHD_SIM_ENABLED=${if enableLLHD then "ON" else "OFF"}"
    "-DMLIR_TABLEGEN_EXE=${lib.getOutput "bin" mlir}/bin/mlir-tblgen" # assumes not-cross for now
    (lib.cmakeBool "BUILD_SHARED_LIBS" buildSharedLibs)
  ]
  ++ lib.optional enableDocs "-DCIRCT_INCLUDE_DOCS=ON"
  ++ lib.optional enableAssertions "-DLLVM_ENABLE_ASSERTIONS=ON"
  ++ lib.optionals enableSlang [
    "-DCIRCT_SLANG_FRONTEND_ENABLED=ON"
    "-DCIRCT_SLANG_BUILD_FROM_SOURCE=OFF"
  ];

  postBuild = lib.optionalString enableDocs ''
    ninja doxygen-circt circt-doc
  '';

  doCheck = true;
  # No integration tests for now, bits aren't working
  checkTarget = "check-circt"; # + " check-circt-integration";

  preCheck = ''
    patchShebangs bin/*.py
  '';

  # Manually install bits that don't have install rules yet.
  postInstall = ''
    install -Dm755 -t $out/bin bin/arcilator-header-cpp.py

    # Doesn't belong in $out/bin, but that's where it's expected for now.
    # $out/share/arcilator/ ?
    install -Dt $out/bin bin/arcilator-runtime.h
  '';

  meta = with lib; {
    description = " Circuit IR Compilers and Tools";
    mainProgram = "firtool";
    homepage = "https://circt.org";
    license = with licenses; [ llvm-exception ];
    maintainers = with maintainers; [ dtzWill ];
  };
}
