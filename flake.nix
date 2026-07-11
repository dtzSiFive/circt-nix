{
  description = "circt-y things";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    slang-src = {
      url = "github:MikePopoloski/slang/v10.0";
      flake = false;
    };

    flake-utils.url = "github:numtide/flake-utils";
    # From README.md: https://github.com/edolstra/flake-compat
    flake-compat = {
      url = "github:edolstra/flake-compat";
      flake = false;
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-compat,
      flake-utils,
      slang-src,
    }:
    let
      # CIRCT release being tracked, kept up to date by ./update-llvm.sh.
      # llvmRev is llvm-project's commit for this release's `llvm`
      # submodule, used only for LLVM's reported version string --
      # circtSrc below is fetched with submodules included, so build
      # content always matches it regardless.
      circtPin = {
        version = "1.152.0";
        rev = "267e183e0121c27f017ce317c2d540cff2834b6f";
        hash = "sha256-VZb5TceGDQO+sLIz2lssKlaRo0bP8WSDWrd9pNiKkQg=";
        llvmRev = "040a641988f6ed6f4fab250706ca2b620c1de2d8";
      };

      overlay =
        final: prev:
        let
          circtSrc = prev.fetchFromGitHub {
            owner = "llvm";
            repo = "circt";
            inherit (circtPin) rev hash;
            fetchSubmodules = true;
          };
          circtFlakePkgs = rec {
            llvmPackages_circt = prev.lib.recurseIntoAttrs (
              prev.callPackages ./llvm.nix {
                inherit circtSrc;
                inherit (circtPin) llvmRev;
                llvmPackages = final.llvmPackages_git;
                # TODO: Get this handled for us, spliced in?
                buildLLVMPackages_circt = final.buildPackages.llvmPackages_circt;
              }
            );
            circt = prev.callPackage ./circt.nix {
              inherit circtSrc;
              inherit (circtPin) version;
              inherit (llvmPackages_circt) libllvm mlir llvm-third-party-src;
              lit = prev.lit.overrideAttrs (o: {
                patches = o.patches or [ ] ++ [
                  ./patches/lit-shell-script-runner-set-dyld-library-path.patch
                ];
              });
              slang = slang;
            };

            espresso = prev.callPackage ./espresso.nix { };
            slang = prev.callPackage ./slang.nix {
              inherit slang-src;
            };
          };
        in
        { inherit circtFlakePkgs; } // circtFlakePkgs;
    in
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ overlay ];
        };
      in
      rec {
        formatter = pkgs.nixfmt;
        devShells = {
          default = import ./shell.nix { inherit pkgs; };
        }
        //
          pkgs.lib.optionalAttrs
            (
              !pkgs.stdenv.isDarwin # libcxxabi git on Darwin is broken?
            )
            {
              git = import ./shell.nix {
                inherit pkgs;
                llvmPkgs = pkgs.llvmPackages_git; # NOT same as submodule.
              };
            };
        packages = (pkgs.lib.removeAttrs pkgs.circtFlakePkgs [ "llvmPackages_circt" ]) // {
          default = pkgs.circt; # default for `nix build` etc.
          # selectively expose packages from llvmPackages_circt.
          # clang/etc are not tested and patches/builds may break.
          inherit (pkgs.circtFlakePkgs.llvmPackages_circt) libllvm mlir;
        };
        apps = pkgs.lib.genAttrs [ "firtool" "circt-lsp-server" "circt-verilog-lsp-server" ] (
          name:
          flake-utils.lib.mkApp {
            drv = packages.circt;
            inherit name;
          }
        );

        # Expose nixpkgs with overlay applied under legacyPackages.
        # Can be used for, e.g., cross-compilation.
        legacyPackages = import nixpkgs {
          inherit system;
          overlays = [ overlay ];
          crossOverlays = [ overlay ];
        };
      }
    )
    // {
      overlays.default = overlay;
    };

  nixConfig = {
    extra-substituters = [ "https://dtz-circt.cachix.org" ];
    extra-trusted-public-keys = [
      "dtz-circt.cachix.org-1:PHe0okMASm5d9SD+UE0I0wptCy58IK8uNF9P3K7f+IU="
    ];
  };
}
