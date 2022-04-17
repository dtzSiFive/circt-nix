{
  description = "circt-y things";


  inputs = {
    # Use Nixpkgs branch until MLIR at least is merged into nixpkgs proper
    nixpkgs.url = "github:dtzWill/nixpkgs/feature/flang";
    circt-src.url = "github:llvm/circt/main";
    circt-src.flake = false;
    llvm-submodule-src = {
      type = "github";
      owner = "llvm";
      repo = "llvm-project";
      # From circt submodule
      rev = "1aa4f0bb6cc21b7666718f5534c88d03152ddfb1";
      flake = false;
    };
    wake-src.url = "github:sifive/wake/v0.24.0";
    wake-src.flake = false;

    flake-utils.url = "github:numtide/flake-utils";
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
            default = circt; # default for `nix build` etc.

            circt = pkgs.callPackage ./circt.nix {
              inherit circt-src;
              inherit (newLLVMPkgs) libllvm mlir llvmUtilsSrc;
            };
            polygeist = pkgs.callPackage ./polygeist.nix {
              inherit (newLLVMPkgs) mlir;
              llvm = newLLVMPkgs.libllvm;
              clang-unwrapped = newLLVMPkgs.libclang;
            };
            wake = pkgs.callPackage ./wake.nix { inherit wake-src; };
          });
        }
      );
}
