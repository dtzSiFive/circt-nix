{ stdenv, lib, cmake, fetchFromGitHub, clang-unwrapped, llvm, mlir, lit }:

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

    substituteInPlace lib/polygeist/Passes/CMakeLists.txt --replace "LINK_LIBS PUBLIC" "LINK_LIBS"

    substituteInPlace CMakeLists.txt --replace @MLIR_TABLEGEN_EXE@ "${mlir}/bin/mlir-tblgen"

    substituteInPlace lib/polygeist/Passes/ConvertPolygeistToLLVM.cpp \
      --replace StdToLLVM FuncToLLVM
    for x in tools/mlir-clang/CMakeLists.txt tools/mlir-clang/mlir-clang.cc lib/polygeist/Passes/ConvertPolygeistToLLVM.cpp; do
      substituteInPlace "$x" --replace StandardToLLVM FuncToLLVM
    done
    substituteInPlace tools/mlir-clang/mlir-clang.cc --replace createLowerToLLVMPass createConvertFuncToLLVMPass

    substituteInPlace tools/polygeist-opt/polygeist-opt.cpp --replace mlir/Support/MlirOptMain.h mlir/Tools/mlir-opt/MlirOptMain.h
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
