{
  description = "circt-y things";


  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/3b7b015de04db0849ef7b929ee5783247c07d80b";
    circt-src.url = "github:llvm/circt";
    circt-src.flake = false;
    llvm-submodule-src = {
      type = "github";
      owner = "llvm";
      repo = "llvm-project";
      # From circt submodule
      rev = "8041c11548017f914ec1b1b6f36d528b56424ee2";
      flake = false;
    };
    slang-src.url = "github:MikePopoloski/slang/dd16a7947e0586d0541477f1b4b60eda7c986e35"; # pinned in CIRCT.  Split out!
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
    }: 
      let
        overlay = final: prev:
          let circtFlakePkgs = rec {
            llvmPackages_circt = prev.lib.recurseIntoAttrs (prev.callPackages ./llvm.nix {
              inherit llvm-submodule-src;
              llvmPackages = final.llvmPackages_git;
              # TODO: Get this handled for us, spliced in?
              buildLLVMPackages_circt = final.buildPackages.llvmPackages_circt;
            });
            circt = prev.callPackage ./circt.nix {
              inherit circt-src;
              inherit (llvmPackages_circt) libllvm mlir llvm-third-party-src;
              lit = prev.lit.overrideAttrs (o: {
                patches = o.patches or [] ++ [
                  ./patches/lit-shell-script-runner-set-dyld-library-path.patch
                ];
              });
              slang = slang_9;
            };

            espresso = prev.callPackage ./espresso.nix {};
            slang = prev.callPackage ./slang.nix {
              inherit slang-src;
            };
            slang_9 = prev.callPackage ./slang_9.nix {};
          };
          in { inherit circtFlakePkgs; } // circtFlakePkgs;
      in flake-utils.lib.eachDefaultSystem (system:
        let pkgs = import nixpkgs { inherit system; overlays = [ overlay ]; };
        in rec {
          devShells = {
            default = import ./shell.nix { inherit pkgs; };
          } // pkgs.lib.optionalAttrs (!pkgs.stdenv.isDarwin /* libcxxabi git on Darwin is broken?*/) {
            git = import ./shell.nix {
               inherit pkgs;
               llvmPkgs = pkgs.llvmPackages_git; # NOT same as submodule.
            };
          };
          packages = (pkgs.lib.removeAttrs pkgs.circtFlakePkgs ["llvmPackages_circt"]) // {
            default = pkgs.circt; # default for `nix build` etc.
            # selectively expose packages from llvmPackages_circt.
            # clang/etc are not tested and patches/builds may break.
            inherit (pkgs.circtFlakePkgs.llvmPackages_circt) libllvm mlir;
          };
          apps = pkgs.lib.genAttrs [ "firtool" "circt-lsp-server" "circt-verilog-lsp-server" ]
            (name: flake-utils.lib.mkApp { drv = packages.circt; inherit name; });

          # Expose nixpkgs with overlay applied under legacyPackages.
          # Can be used for, e.g., cross-compilation.
          legacyPackages = import nixpkgs {
            inherit system;
            overlays = [ overlay ];
            crossOverlays = [ overlay ];
          };
        }
      ) // { overlays.default = overlay; };

  nixConfig = {
    extra-substituters = [ "https://dtz-circt.cachix.org" ];
    extra-trusted-public-keys = [ "dtz-circt.cachix.org-1:PHe0okMASm5d9SD+UE0I0wptCy58IK8uNF9P3K7f+IU=" ];
  };
}
