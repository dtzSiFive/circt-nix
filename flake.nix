{
  description = "circt-y things";


  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs";
    circt-src.url = "github:llvm/circt";
    circt-src.flake = false;
    llvm-submodule-src = {
      type = "github";
      owner = "llvm";
      repo = "llvm-project";
      # From circt submodule
      rev = "289b17635958d986b74683c932df6b1d12f37b70";
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
        let
          overlay = self: super:
            let circtFlakePkgs = rec {
              llvmPackages_circt = super.callPackage ./llvm.nix {
                inherit llvm-submodule-src;
                llvmPackages = self.llvmPackages_git;
              };
              circt = super.callPackage ./circt.nix {
                inherit circt-src;
                inherit (llvmPackages_circt) libllvm mlir llvm-third-party-src;
                slang = slang_3;
              };

              espresso = super.callPackage ./espresso.nix {};
              slang = super.callPackage ./slang.nix {
                inherit slang-src;
              };
              slang_3 = super.callPackage ./slang_3.nix {};
              lit = super.lit.overrideAttrs (o: {
                patches = o.patches or [] ++ [
                  ./patches/lit-shell-script-runner-set-dyld-library-path.patch
                ];
              });
          }; in { inherit circtFlakePkgs; } // circtFlakePkgs;
          pkgs = import nixpkgs { inherit system; overlays = [ overlay ]; };
        in rec {
          devShells = {
            default = import ./shell.nix { inherit pkgs; };
          } // pkgs.lib.optionalAttrs (!pkgs.stdenv.isDarwin /* libcxxabi git on Darwin is broken?*/) {
            git = import ./shell.nix {
               inherit pkgs;
               llvmPkgs = pkgs.llvmPackages_git; # NOT same as submodule.
            };
          };
          packages = flake-utils.lib.flattenTree (pkgs.circtFlakePkgs // {
            default = pkgs.circt; # default for `nix build` etc.
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
