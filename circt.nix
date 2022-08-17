{ lib, stdenv, cmake
, libllvm, mlir, lit
, circt-src
, capnproto, verilator
, python3
, llvmUtilsSrc
, ninja
, doxygen
, graphviz-nox
, enableAssertions ? true
}:


# TODO: or-tools, needs cmake bits maybe?
stdenv.mkDerivation {
  pname = "circt";
  version = "1.12.0-git-${circt-src.shortRev}";
  nativeBuildInputs = [ cmake python3 ninja doxygen graphviz-nox ];
  buildInputs = [ mlir libllvm capnproto verilator ];
  src = circt-src;

  patches = [
    ./patches/circt-mlir-tblgen-path.patch
  ];
  postPatch = ''
    substituteInPlace CMakeLists.txt --replace @MLIR_TABLEGEN_EXE@ "${mlir}/bin/mlir-tblgen"
  '';

  cmakeFlags = [
    "-DLLVM_DIR=${libllvm}/lib/cmake/llvm"
    "-DLLVM_EXTERNAL_LIT=${lit}/bin/lit"
    "-DLLVM_LIT_ARGS=-v"
    "-DCapnProto_DIR=${capnproto}/lib/cmake/CapnProto"
    "-DLLVM_BUILD_MAIN_SRC_DIR=${llvmUtilsSrc}"
    "-DCIRCT_INCLUDE_DOCS=ON"
  ] ++ lib.optional enableAssertions "-DLLVM_ENABLE_ASSERTIONS=ON";

  postBuild = "ninja doxygen-circt circt-doc";

  doCheck = true;
  # No integration tests for now, bits aren't working
  checkTarget = "check-circt"; # + " check-circt-integration";

  preCheck = ''
    export LD_LIBRARY_PATH=$LD_LIBRARY_PATH''${LD_LIBRARY_PATH:+:}$PWD/lib

    patchShebangs bin/*.py
  '';

  meta = with lib; {
    description = " Circuit IR Compilers and Tools";
    homepage = "https://circt.org";
    license = with licenses; [ asl20 llvm-exception ];
    maintainers = with maintainers; [ dtzWill ];
  };
}
