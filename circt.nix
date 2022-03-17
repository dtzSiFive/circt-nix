{ stdenv, cmake
, libllvm, mlir, lit
, circt-src
, capnproto, verilator
, python3
}:


# TODO: or-tools, needs cmake bits maybe?
stdenv.mkDerivation {
  pname = "circt";
  version = "0.0.8-git-${circt-src.shortRev}";
  nativeBuildInputs = [ cmake python3 ];
  buildInputs = [ mlir libllvm capnproto verilator ];
  src = circt-src;

  patches = [
    ./patches/circt-mlir-tblgen-path.patch
    ./patches/circt-no-test-deps-mlir-utils.patch
  ];
  postPatch = ''
    substituteInPlace CMakeLists.txt --replace @MLIR_TABLEGEN_EXE@ "${mlir}/bin/mlir-tblgen"
  '';
  cmakeFlags = [
    "-DLLVM_DIR=${libllvm}/lib/cmake/llvm"
    "-DLLVM_EXTERNAL_LIT=${lit}/bin/lit"
    "-DLLVM_LIT_ARGS=-v"
    "-DCapnProto_DIR=${capnproto}/lib/cmake/CapnProto"
  ];

  doCheck = true;
  checkTarget = "check-circt check-circt-integration";

  preCheck = ''
    export LD_LIBRARY_PATH=$LD_LIBRARY_PATH''${LD_LIBRARY_PATH:+:}$PWD/lib

    patchShebangs bin/*.py
  '';
}
