{
  description = "circt-y things";


  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/9af629d964124ab36b339699513a0135f1acd7f2";
    circt-src.url = "github:llvm/circt";
    circt-src.flake = false;
    llvm-submodule-src = {
      type = "github";
      owner = "llvm";
      repo = "llvm-project";
      # From circt submodule
      rev = "76bebb5be9daf9ca035777b17fa63d4ce13e79b9";
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
    }: 
      let
        overlay = final: prev:
          let circtFlakePkgs = rec {
            llvmPackages_circt = prev.lib.recurseIntoAttrs (prev.callPackages ./llvm.nix {
              inherit llvm-submodule-src;
              llvmPackages = final.llvmPackages_git;
              buildLLVMPackages_circt = final.buildPackages.llvmPackages_circt;
            });
            circt = prev.callPackage ./circt.nix {
              inherit circt-src;
              inherit (llvmPackages_circt) libllvm mlir llvm-third-party-src;
              slang = slang_3;
              lit = prev.lit.overrideAttrs (o: {
                patches = o.patches or [] ++ [
                  ./patches/lit-shell-script-runner-set-dyld-library-path.patch
                ];
              });
            };

            espresso = prev.callPackage ./espresso.nix {};
            slang = prev.callPackage ./slang.nix {
              inherit slang-src;
            };
            slang_3 = prev.callPackage ./slang_3.nix {};
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
