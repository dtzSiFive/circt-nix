{ pkgs ? import <nixpkgs> {} }:

let

  mlir-llvm = llvm: llvm.overrideAttrs(o: {
    cmakeFlags = o.cmakeFlags ++ [
      "-DLLVM_ENABLE_ASSERTIONS=ON"
      "-DLLVM_ENABLE_PROJECTS=mlir"
    ];

    postPatch = o.postPatch or "" + ''
      pwd
      ls
      echo ------
      ls projects
      echo ------
      chmod u+rw -R mlir
    '';
  });
  llvmTest = mlir-llvm pkgs.llvmPackages_latest.llvm;

in

  llvmTest

