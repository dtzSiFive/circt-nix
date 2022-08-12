{ stdenv, lib, cmake, fetchFromGitHub, clang-unwrapped, llvm, mlir, lit }:

stdenv.mkDerivation {
  pname = "polygeist";
  version = "unstable-2022-08-12";

  src = fetchFromGitHub {
    owner = "wsmoses";
    repo = "polygeist";
    rev = "5a6e23b3c4a52f3a9a0294751c8e1f2be98a8b95";
    sha256 = "sha256-4RKRKYeZZp0/hWAbyQozO6NewqZSUE9jUWpwSt0w6yY=";
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
    install -Dm755 bin/{cgeist,polygeist-opt} -t $out/bin
  '';

  # 'cgeist' can't find headers, is at least a big cause of failures
  doCheck = false;

  #checkTarget = "check-all";
  checkTarget = "check-cgeist check-polygeist-opt";
}
