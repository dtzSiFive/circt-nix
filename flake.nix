{
  description = "circt-y things";


  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
    circt-src = {
      type = "github";
      owner = "llvm";
      repo = "circt";
      #submodules = true;
      ref = "main";
      flake = false;
    };
    #circt-git-src = {
    #  type = "git";
    #  url = "https://github.com/llvm/circt";
    #  ref = "main";
    #  flake = false;
    #  submodules = true;
    #};
    llvm-submodule-src = {
      type = "github";
      owner = "llvm";
      repo = "llvm-project";
      # From circt submodule
      rev = "61814586620deca51ecf6477e19c6afa8e28ad90";
      flake = false;
    };
    nixpkgs = {
      type = "github";
      #owner = "NixOS";
      owner = "dtzWill";
      repo = "nixpkgs";
      ref = "feature/flang";
      #ref = "mast
    };
    wake-src = {
      type = "github";
      owner = "sifive";
      repo = "wake";
      ref = "v0.24.0";
      flake = false;
    };
    # From README.md: https://github.com/edolstra/flake-compat
    flake-compat = {
      url = github:edolstra/flake-compat;
      flake = false;
    };
  };

  outputs = { self
    , nixpkgs
    , flake-compat, flake-utils
    , circt-src, llvm-submodule-src
    , wake-src }: flake-utils.lib.eachDefaultSystem
      (system:
        let pkgs = nixpkgs.legacyPackages.${system};
            newLLVMPkgs = pkgs.callPackage ./llvm.nix {
              inherit llvm-submodule-src;
              llvmPackages = pkgs.llvmPackages_14;
            };
        in rec {
          #devShell = import ./shell.nix { inherit pkgs; };
          packages = flake-utils.lib.flattenTree (newLLVMPkgs // rec {
            circt = pkgs.callPackage ./circt.nix {
              inherit circt-src;
              inherit (newLLVMPkgs) libllvm mlir;
            };
            polygeist = pkgs.callPackage ./polygeist.nix {
              inherit (newLLVMPkgs) mlir;
              llvm = newLLVMPkgs.libllvm;
              clang-unwrapped = newLLVMPkgs.libclang;
            };
            wake = pkgs.callPackage ./wake.nix { inherit wake-src; };
          });
          defaultPackage = packages.circt;
        }
      );
}
