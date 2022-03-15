{ stdenv, cmake
, libllvm, mlir, lit
, circt-src
}:


stdenv.mkDerivation {
  pname = "circt";
  version = "0.0.8-git-${circt-src.shortRev}";
  nativeBuildInputs = [ cmake ];
  buildInputs = [ mlir libllvm ];
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
  ];

  doCheck = true;
  checkTarget = "check-circt";

  preCheck = ''
    export LD_LIBRARY_PATH=$LD_LIBRARY_PATH''${LD_LIBRARY_PATH:+:}$PWD/lib
  '';
}
