{
  description = "circt-y things";


  inputs = {
    # Use Nixpkgs branch until MLIR at least is merged into nixpkgs proper
    nixpkgs.url = "github:dtzWill/nixpkgs/mlir-git";
    circt-src.url = "github:llvm/circt";
    circt-src.flake = false;
    circt-const-src.url = "github:llvm/circt/dev/trilorez/firrtl-const-fir"; # integration branch currently
    circt-const-src.flake = false;
    circt-ref-src.url = "github:dtzSiFive/circt/feature/reftypes-firrtl";
    circt-ref-src.flake = false;
    circt-slang-src.url = "github:fabianschuiki/circt/slang-frontend";
    circt-slang-src.flake = false;
    llvm-submodule-src = {
      type = "github";
      owner = "llvm";
      repo = "llvm-project";
      # From circt submodule
      rev = "bcb8a94503887250d3a818a6b631899e9233080c";
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
    , circt-slang-src
    , circt-const-src
    , circt-ref-src
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
            };
            circt-const = circt.override { circt-src = circt-const-src; };
            circt-ref = circt.override { circt-src = circt-ref-src; };
            circt-slang = circt.override {
              circt-src = circt-slang-src;
              inherit slang;
              enableSlang = true;
            };
            espresso = pkgs.callPackage ./espresso.nix {};
            slang = pkgs.callPackage ./slang.nix {
              inherit slang-src;
            };
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
