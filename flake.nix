{
  description = "circt-y things";


  inputs = {
    nixpkgs.url = "github:dtzWill/nixpkgs/feature/flang"; # /feature/flang";

    circt-src.url = "github:llvm/circt/main";
    circt-src.flake = false;
    llvm-submodule-src = {
      type = "github";
      owner = "llvm";
      repo = "llvm-project";
      # From circt submodule
      rev = "61814586620deca51ecf6477e19c6afa8e28ad90";
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
    nixpkgs-lit.url = "github:dtzWill/nixpkgs/fix/lit-psutil";
  };

  outputs = { self
    , nixpkgs, nixpkgs-lit
    , flake-compat, flake-utils
    , circt-src, llvm-submodule-src
    , wake-src }: flake-utils.lib.eachDefaultSystem
      (system:
        let pkgs = nixpkgs.legacyPackages.${system};
            newLLVMPkgs = pkgs.callPackage ./llvm.nix {
              inherit llvm-submodule-src;
              llvmPackages = pkgs.llvmPackages_14;
            };
            lit = nixpkgs-lit.legacyPackages.${system}.lit;
        in rec {
          #devShell = import ./shell.nix { inherit pkgs; };
          packages = flake-utils.lib.flattenTree (newLLVMPkgs // rec {
            default = circt; # default for `nix build` etc.
            inherit lit;

            circt = pkgs.callPackage ./circt.nix {
              inherit circt-src;
              inherit (newLLVMPkgs) libllvm mlir;
              inherit lit;
            };
            polygeist = pkgs.callPackage ./polygeist.nix {
              inherit (newLLVMPkgs) mlir;
              llvm = newLLVMPkgs.libllvm;
              clang-unwrapped = newLLVMPkgs.libclang;
              inherit lit;
            };
            wake = pkgs.callPackage ./wake.nix { inherit wake-src; };
          });
        }
      );
}
