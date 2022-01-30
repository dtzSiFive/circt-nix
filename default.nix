{ pkgs ? import <nixpkgs> {} }:

let

  ##
  # Plan:
  # Fetch circt tree all-at-once.
  # * don't need all of the pinned llvm-project (probably), maybe drop what's not needed post-unpack
  # Build llvm, mlir, using nix bits but pinned source
  # Build mlir separately?

  # Build circt separately (per instructions)

  # circt (source) as flake input? >:D

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
      find .
      chmod u+rw -R mlir
    '';
  });
  llvmTest = mlir-llvm pkgs.llvmPackages_latest.llvm;

in

  llvmTest

