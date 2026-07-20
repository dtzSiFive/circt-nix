{
  description = "circt-y things";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    # Pinned to the exact commit CIRCT's CMakeLists.txt FetchContent-pins
    # (v11.0 + ~85 commits). CIRCT's ImportVerilog tests are tuned to this
    # revision's diagnostics (llvm/circt#10717), so a plain v11.0 release
    # tag is not sufficient -- keep this in sync with CIRCT's GIT_TAG.
    slang-src = {
      url = "github:MikePopoloski/slang/44dc55f99b9c64971893013e7931e643fbedcf23";
      flake = false;
    };

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
      slang-src,
    }:
    let
      inherit (nixpkgs) lib;

      # Systems we build for.
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
      ];

      # Helper utilities for our flake.
      # "Borrowed" from flake-utils.
      #
      # eachSystem: call `f system` for each system and transpose the
      # results, so `{ packages = ...; }` per system becomes the flake's
      # `{ packages.<system> = ...; }`. Attrs missing on some systems are
      # only emitted for the systems that provide them.
      eachSystem =
        f:
        let
          perSystem = lib.genAttrs systems f;
          attrNames = lib.unique (lib.concatMap lib.attrNames (lib.attrValues perSystem));
        in
        lib.genAttrs attrNames (
          attr:
          lib.genAttrs (lib.filter (system: perSystem.${system} ? ${attr}) systems) (
            system: perSystem.${system}.${attr}
          )
        );

      # mkApp: build a flake `app` output pointing at a binary in `drv`.
      mkApp = { drv, name ? drv.meta.mainProgram or drv.pname, }:
        { type = "app"; program = "${drv}/bin/${name}"; };

      # CIRCT release being tracked, kept up to date by ./update-llvm.sh.
      # llvmRev is llvm-project's commit for this release's `llvm`
      # submodule, used only for LLVM's reported version string --
      # circtSrc below is fetched with submodules included, so build
      # content always matches it regardless.
      circtPin = {
        version = "1.153.1";
        rev = "930f444d6bd072c1111b693f30c5795455d4ea7b";
        hash = "sha256-pxIJE3IHn2A996kGMTtMeTH7WdYn4Enhf0cLYrPC9xY=";
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
              # CIRCT statically links slang (libsvlang.a), so this variant is
              # embedded in CIRCT and never shipped as a CLI -- disabling
              # threads here matches how CIRCT configures slang when it builds
              # it from source, while leaving the standalone `slang` package
              # (with its -j option) untouched.
              slang = slang.override { enableThreads = false; };
            };

            espresso = prev.callPackage ./espresso.nix { };
            slang = prev.callPackage ./slang.nix {
              inherit slang-src;
            };
          };
        in
        { inherit circtFlakePkgs; } // circtFlakePkgs;
    in
    eachSystem (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ overlay ];
        };
      in
      rec {
        formatter = pkgs.nixfmt-tree;
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
          mkApp {
            drv = packages.circt;
            inherit name;
          }
        );

        # Expose nixpkgs with the overlay applied under legacyPackages.
        #
        # Was a second `import nixpkgs` that also passed
        # `crossOverlays = [ overlay ]` (f8b2b85), i.e. an extra nixpkgs
        # instantiation per system. Redundant: plain `overlays` already
        # reaches cross sets -- pkgsCross.*.circt still evaluates without it
        # -- so crossOverlays only applied the overlay a *second* time to the
        # cross stage. That double application perturbed derivations (native
        # `hello` included, so legacyPackages.<pkg> silently diverged from
        # packages.<pkg>) and made tomlplusplus and glibc-iconv hit infinite
        # recursion. Not specific to our overlay: a trivial
        # `{ probe = 42; }` crossOverlay reproduces it.
        legacyPackages = pkgs;
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
