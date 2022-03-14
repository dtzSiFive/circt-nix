{ stdenv, cmake, fetchFromGitHub, clang-unwrapped, llvm, mlir }:

stdenv.mkDerivation {
  pname = "polygeist";
  version = "unstable-2022-03-09";

  src = fetchFromGitHub {
    owner = "wsmoses";
    repo = "polygeist";
    rev = "6ba6b7b8ac07c9d60994eb46b46682a9f76ea34e";
    sha256 = "sha256-tkraEngeC1Ko8JS+e2gxOQBP1VWEfbGptkC+DLN46aU=";
  };

  nativeBuildInputs = [ cmake ];
  buildInputs = [ llvm mlir ];

  cmakeFlags = [
    "-DLLVM_DIR=${llvm.dev}/lib/cmake/llvm"
    "-DCLANG_DIR=${clang-unwrapped.dev}/lib/cmake/clang"
    "-DMLIR_DIR=${mlir.dev}/lib/cmake/mlir"
  ];

  postPatch = ''
    substituteInPlace tools/mlir-clang/CMakeLists.txt \
      --replace '"''${LLVM_SOURCE_DIR}/../clang' \
                '"${clang-unwrapped.src}/clang'
  '';
}
