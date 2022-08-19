{
  description = "circt-y things";


  inputs = {
    # Use Nixpkgs branch until MLIR at least is merged into nixpkgs proper
    nixpkgs.url = "github:dtzWill/nixpkgs/mlir-git";
    circt-src.url = "github:llvm/circt";
    #circt-src.url = "github:llvm/circt/update/llvm-47.2";
    circt-src.flake = false;
    llvm-submodule-src = {
      type = "github";
      owner = "llvm";
      repo = "llvm-project";
      # From circt submodule
      rev = "fe0f72d5c55a9b95c5564089e946e8f08112e995";
      flake = false;
    };

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
    }: flake-utils.lib.eachDefaultSystem
      (system:
        let pkgs = nixpkgs.legacyPackages.${system};
            newLLVMPkgs = pkgs.callPackage ./llvm.nix {
              inherit llvm-submodule-src;
              llvmPackages = pkgs.llvmPackages_git;
            };
        in rec {
          devShell = import ./shell.nix { inherit pkgs; };
          packages = flake-utils.lib.flattenTree (newLLVMPkgs // rec {
            default = circt; # default for `nix build` etc.

            circt = pkgs.callPackage ./circt.nix {
              inherit circt-src;
              inherit (newLLVMPkgs) libllvm mlir llvmUtilsSrc;
            };
          });
        }
      );
}
