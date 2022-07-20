{ stdenv, lib, cmake, fetchFromGitHub, clang-unwrapped, llvm, mlir, lit }:

stdenv.mkDerivation {
  pname = "polygeist";
  version = "unstable-2022-06-25";

  src = fetchFromGitHub {
    owner = "wsmoses";
    repo = "polygeist";
    rev = "e703db13174c60d590885ecc4b1a47dcc370c282";
    sha256 = "sha256-SDQ0SGfzXwQPyIeSRjmyjH1y6aWUupzAtUMci/prRwc=";
  };

  nativeBuildInputs = [ cmake ];
  buildInputs = [ llvm mlir ];

  cmakeFlags = [
    "-DLLVM_DIR=${lib.getDev llvm}/lib/cmake/llvm"
    "-DCLANG_DIR=${lib.getDev clang-unwrapped}/lib/cmake/clang"
    "-DMLIR_DIR=${lib.getDev mlir}/lib/cmake/mlir"
    # "-DMLIR_TABLEGEN_EXE=${lib.getBin mlir}/bin/mlir-tblgen"
    "-DLLVM_EXTERNAL_LIT=${lit}/bin/lit"
  ];

  patches = [ ./patches/polygeist-mlir-tblgen-path.patch ];

  postPatch = ''
    substituteInPlace tools/mlir-clang/CMakeLists.txt \
      --replace '"''${LLVM_SOURCE_DIR}/../clang' \
                '"${clang-unwrapped.src}/clang'

    substituteInPlace CMakeLists.txt --replace @MLIR_TABLEGEN_EXE@ "${mlir}/bin/mlir-tblgen"
  '';

  postInstall = ''
    mkdir -p $out/bin
    install -Dm755 bin/{mlir-clang,polygeist-opt} -t $out/bin
  '';

  # 'mlir-clang' can't find headers, is at least a big cause of failures
  doCheck = false;

  #checkTarget = "check-all";
  checkTarget = "check-mlir-clang check-polygeist-opt";
}
