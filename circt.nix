{ lib, fetchpatch
, stdenv, cmake, pkg-config
, gnugrep
, coreutils
, libllvm, mlir, lit
, circt-src
, capnproto
, verilator
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
, withVerilator ? !stdenv.hostPlatform.isDarwin
, z3
}:


# TODO: or-tools, needs cmake bits maybe?
let
  mkVer = src:
    let
      date = builtins.substring 0 8 (src.lastModifiedDate or src.lastModified or "19700101");
      rev = src.shortRev or "dirty";
    in
      "g${date}_${rev}";

  tag = "1.58.0";
  versionSuffix = mkVer circt-src;
  version = "${tag}${versionSuffix}";
in stdenv.mkDerivation {
  pname = "circt";
  inherit version;
  nativeBuildInputs = [ cmake python3 ninja pkg-config ]
    ++ lib.optionals enableDocs [ doxygen graphviz-nox ];
  buildInputs = [ mlir libllvm capnproto z3 ]
    ++ lib.optionals enableOrTools [ or-tools bzip2 cbc eigen glpk re2 ]
    ++ lib.optional enableSlang [ slang ]
    ++ lib.optional withVerilator [ verilator ];
  src = circt-src;

  patches = [
    ./patches/circt-mlir-tblgen-path.patch
  ];
  postPatch = ''
    substituteInPlace CMakeLists.txt --replace @MLIR_TABLEGEN_EXE@ "${mlir}/bin/mlir-tblgen"

    substituteInPlace cmake/modules/GenVersionFile.cmake \
      --replace '"unknown git version"' '"${version}"'
    
    find test -type f -exec \
      sed -i -e 's,--test /usr/bin/env,--test ${lib.getBin coreutils}/bin/env,' \{\} \;
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
    license = with licenses; [ asl20-llvm];
    maintainers = with maintainers; [ dtzWill ];
  };
}
