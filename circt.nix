{ lib, fetchpatch
, stdenv, cmake, pkg-config
, gnugrep
, libllvm, mlir, lit
, circt-src
, capnproto, verilator
# TODO: Shouldn't need to specify these deps, fix in upstream nixpkgs!
, or-tools, bzip2, cbc, eigen, glpk, re2
, python3
, llvm-third-party-src
, ninja
, doxygen
, graphviz-nox
, enableDocs ? false
, enableAssertions ? true
, enableOrTools ? false # stdenv.hostPlatform.isLinux
, slang
, enableSlang ? false
}:


# TODO: or-tools, needs cmake bits maybe?
let
  mkVer = src:
    let
      date = builtins.substring 0 8 (src.lastModifiedDate or src.lastModified or "19700101");
      rev = src.shortRev or "dirty";
    in
      "g${date}_${rev}";

  tag = "1.22.0";
  versionSuffix = mkVer circt-src;
  version = "${tag}${versionSuffix}";
in stdenv.mkDerivation {
  pname = "circt";
  inherit version;
  nativeBuildInputs = [ cmake python3 ninja pkg-config ]
    ++ lib.optionals enableDocs [ doxygen graphviz-nox ];
  buildInputs = [ mlir libllvm capnproto verilator ]
    ++ lib.optionals enableOrTools [ or-tools bzip2 cbc eigen glpk re2 ]
    ++ lib.optional enableSlang [ slang ];
  src = circt-src;

  patches = [
    ./patches/circt-mlir-tblgen-path.patch
  ] ++ lib.optional enableSlang [
    (fetchpatch {
     name = "llvm-bump.patch";
     url = "https://github.com/llvm/circt/commit/2f7ad73e385c4a0b646fca3d47912d768a26eadb.patch";
     sha256 = "DqzSQAu1GCgf4C+nMszTjcE4BFhe7saR+KLJj8zIGdw=";
     excludes = [ "llvm" ];
     })
    (fetchpatch {
      name = "llvm-bump-4353.patch";
      url = "https://github.com/llvm/circt/pull/4353.patch";
      sha256 = "54dEx8wEzHJCP0uz0t3+h850kpU3iNToB7lgEMZB6h4=";
      excludes = [ "llvm" ];
    })
  ];
  postPatch = ''
    substituteInPlace CMakeLists.txt --replace @MLIR_TABLEGEN_EXE@ "${mlir}/bin/mlir-tblgen"

    substituteInPlace cmake/modules/GenVersionFile.cmake \
      --replace '"unknown git version"' '"${version}"'
    
    # No /usr/bin/env in sandbox.  Just replace with full 'grep' utility path:
    substituteInPlace test/circt-reduce/test/annotation-remover.mlir \
      --replace '--test /usr/bin/env --test-arg grep' \
                '--test "${lib.getBin gnugrep}/bin/grep"'
  ''
  # slang library renamed to 'svlang'.
  + lib.optionalString enableSlang ''
    substituteInPlace lib/Conversion/ImportVerilog/CMakeLists.txt \
      --replace slang::slang slang::svlang

    # Bad interaction with hardcoded flags + LLVM machinery for exceptions/etc.
    substituteInPlace CMakeLists.txt --replace "-fno-exceptions -fno-rtti" ""
  '';
 

  outputs = [ "out" "lib" "dev" ];

  cmakeFlags = [
    "-DLLVM_EXTERNAL_LIT=${lit}/bin/lit"
    "-DLLVM_LIT_ARGS=-v"
    "-DLLVM_THIRD_PARTY_DIR=${llvm-third-party-src}"
  ] ++ lib.optional enableDocs "-DCIRCT_INCLUDE_DOCS=ON"
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
    export LD_LIBRARY_PATH=$LD_LIBRARY_PATH''${LD_LIBRARY_PATH:+:}$PWD/lib

    patchShebangs bin/*.py
  '';

  meta = with lib; {
    description = " Circuit IR Compilers and Tools";
    mainProgram = "firtool";
    homepage = "https://circt.org";
    license = with licenses; [ asl20 llvm-exception ]; # (ASL2.0 w/LLVM Exception)
    maintainers = with maintainers; [ dtzWill ];
  };
}
