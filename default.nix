{ pkgs ? import <nixpkgs> {}, circt-src }:

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
    src = "${circt-src}/llvm";
    sourceRoot = "llvm/llvm";
    cmakeFlags = o.cmakeFlags ++ [
      "-DLLVM_ENABLE_ASSERTIONS=ON"
      "-DLLVM_ENABLE_PROJECTS=mlir"
    ];

    postPatch = o.postPatch or "" + ''
      # create with sane permissions
      mkdir -p build/lib/cmake/mlir
      echo "-------"
      pwd
      ls -la
      chmod u+rw -R ..
    '';
    #prePatch = o.prePatch or "" + ''
    #  pwd
    #  ls
    #  echo ------
    #  find .
    #'';
  });
  llvmTest = mlir-llvm pkgs.llvmPackages_14.llvm;

in

  llvmTest

