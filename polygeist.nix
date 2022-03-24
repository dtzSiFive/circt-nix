{ stdenv, lib, cmake, fetchFromGitHub, clang-unwrapped, llvm, mlir, lit }:

stdenv.mkDerivation {
  pname = "polygeist";
  version = "unstable-2022-03-24";

  src = fetchFromGitHub {
    owner = "wsmoses";
    repo = "polygeist";
    rev = "e7489c467b85c7275ee0ac21a5498801bc071c69";
    sha256 = "sha256-wVVP9Eg7r/aPq26sg58XZ4KuGVTzerazxVBrpxLuhxc=";
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
