{ pkgs ? import <nixpkgs> {} }:

let

  mlir-llvm = llvm: llvm.overrideAttrs(o: {
    cmakeFlags = o.cmakeFlags ++ [
      "-DLLVM_ENABLE_ASSERTIONS=ON"
      "-DLLVM_ENABLE_PROJECTS=mlir"
    ];
  });
  llvmTest = mlir-llvm pkgs.llvmPackages_latest.llvm;

in

  llvmTest

