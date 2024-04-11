{
  description = "circt-y things";


  inputs = {
    # Use Nixpkgs branch until MLIR at least is merged into nixpkgs proper
    nixpkgs.url = "github:dtzWill/nixpkgs/mlir-git";
    circt-src.url = "github:llvm/circt";
    circt-src.flake = false;
    llvm-submodule-src = {
      type = "github";
      owner = "llvm";
      repo = "llvm-project";
      # From circt submodule
      rev = "20ed5b1f45871612570d3bd447121ac43e083c6a";
      flake = false;
    };
    slang-src.url = "github:MikePopoloski/slang";
    slang-src.flake = false;

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
    , slang-src
    }: flake-utils.lib.eachDefaultSystem
      (system:
        let pkgs = nixpkgs.legacyPackages.${system};
            newLLVMPkgs = pkgs.callPackage ./llvm.nix {
              inherit llvm-submodule-src;
              llvmPackages = pkgs.llvmPackages_git;
            };
        in rec {
          devShells = {
            default = import ./shell.nix { inherit pkgs; };
          } // pkgs.lib.optionalAttrs (!pkgs.stdenv.isDarwin /* libcxxabi git on Darwin is broken?*/) {
            git = import ./shell.nix {
               inherit pkgs;
               llvmPkgs = pkgs.llvmPackages_git; # NOT same as submodule.
            };
          };
          packages = flake-utils.lib.flattenTree (newLLVMPkgs // rec {
            default = circt; # default for `nix build` etc.

            circt = pkgs.callPackage ./circt.nix {
              inherit circt-src;
              inherit (newLLVMPkgs) libllvm mlir llvm-third-party-src;
              slang = slang_3;
            };
            espresso = pkgs.callPackage ./espresso.nix {};
            slang = pkgs.callPackage ./slang.nix {
              inherit slang-src;
            };
            slang_3 = pkgs.callPackage ./slang_3.nix {};
          });
          apps = pkgs.lib.genAttrs [ "firtool" "circt-lsp-server" ]
            (name: flake-utils.lib.mkApp { drv = packages.circt; inherit name; });
        }
      );

  nixConfig = {
    extra-substituters = [ "https://dtz-circt.cachix.org" ];
    extra-trusted-public-keys = [ "dtz-circt.cachix.org-1:PHe0okMASm5d9SD+UE0I0wptCy58IK8uNF9P3K7f+IU=" ];
  };
}
