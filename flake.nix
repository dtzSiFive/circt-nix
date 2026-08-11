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
      mkApp =
        {
          drv,
          name ? drv.meta.mainProgram or drv.pname,
        }:
        {
          type = "app";
          program = "${drv}/bin/${name}";
        };

      # CIRCT release being tracked, kept up to date by ./update-llvm.sh.
      # llvmRev is llvm-project's commit for this release's `llvm`
      # submodule, used only for LLVM's reported version string --
      # circtSrc below is fetched with submodules included, so build
      # content always matches it regardless.
      circtPin = {
        version = "1.155.0";
        rev = "be4ed8ff94d7f8e0a1bf92fb59b30ddfdf2ec104";
        hash = "sha256-a64OuNuu2FHONVgG0+V2RYPq+V18rrQGdcXS6hwoTks=";
        llvmRev = "f1ba92abeffcd4d262d70843fa083c10b179cb4d";
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

              # Override nixpkgs' lit, it uses pypi which is pinned to 18.1.8.
              # We need newer version. Fix this upstream!
              lit = prev.lit.overrideAttrs (o: {
                name = "lit-${llvmPackages_circt.libllvm.version}";
                version = llvmPackages_circt.libllvm.version;
                src = "${circtSrc}/llvm/llvm/utils/lit";
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

            # CIRCT with the option-clean tools folded into one multicall
            # binary (bin/circt-driver + symlinks): software multiplexing
            # (Dietz & Adve, OOPSLA 2018, doi:10.1145/3276524) as automatic
            # multicall, built from the local feature/circt-multicall-v2
            # branch. That branch's llvm submodule is the same rev as
            # circtPin's, so libllvm/mlir above are reused as-is and only
            # CIRCT itself rebuilds.
            #
            # Plugin hosting is kept ON (the branch default): the driver
            # exports its symbols so --load-pass-plugin and friends resolve
            # against it. That pins the folded union as GC roots (measured on
            # the branch, Release: 175.4 -> 274.4 MB), so link with lld's
            # --icf=all to fold identical code back down (274.4 -> 231.3 on
            # the branch). A build that never loads plugins can add
            # -DCIRCT_TOOLS_DRIVER_PLUGIN_SUPPORT=OFF to reclaim the rest.
            circt-multicall =
              let
                branchSrc = builtins.fetchGit {
                  url = "file:///home/will/src/sifive/circt";
                  ref = "refs/heads/feature/circt-multicall-v2";
                  rev = "f13084d794e65d63bc5cd7027f3f46d3c1cd66cc";
                };
                # fetchGit leaves the llvm submodule as an empty directory;
                # graft in the pinned source's copy (same rev, b1c56fb53a9c).
                srcWithLLVM = prev.runCommand "circt-multicall-src" { } ''
                  cp -r ${branchSrc} $out
                  chmod -R u+w $out
                  rm -rf $out/llvm
                  cp -r ${circtSrc}/llvm $out/llvm
                '';
                # nixpkgs stdenvAdapters has useGoldLinker/useMoldLinker/
                # useWildLinker but no useLLDLinker; roll one (native-only: no
                # target-prefix handling). Upstream candidate.
                #
                # NOT the mold adapter's raw-symlink trick: a raw linker
                # bypasses ld-wrapper.sh, so binaries lose the RUNPATHs it
                # injects per -L dir -- the freshly linked circt-tblgen then
                # dies mid-build unable to find libz. Instead merge ld.lld
                # into the unwrapped binutils: the bintools wrapper's `ld.*`
                # glob then wraps it exactly like ld.gold, rpath handling and
                # all.
                useLLDLinker =
                  stdenv:
                  let
                    bintoolsUnwrapped = prev.symlinkJoin {
                      name = "${prev.binutils-unwrapped.name}-with-lld";
                      paths = [
                        prev.binutils-unwrapped
                        prev.buildPackages.lld
                      ];
                      inherit (prev.binutils-unwrapped) passthru;
                    };
                    bintools = stdenv.cc.bintools.override {
                      bintools = bintoolsUnwrapped;
                    };
                  in
                  stdenv.override (old: {
                    allowedRequisites = null;
                    cc = stdenv.cc.override { inherit bintools; };
                  });
              in
              (circt.override {
                stdenv = useLLDLinker prev.stdenv;
                version = "1.154.0-multicall";
              }).overrideAttrs
                (o: {
                  pname = "circt-multicall";
                  src = srcWithLLVM;
                  # The branch moved this patch's context in test/lit.cfg.py;
                  # same payload, regenerated against the branch.
                  patches =
                    (prev.lib.filter (
                      p: baseNameOf p != "circt-lit-dylib-paths.patch"
                    ) o.patches)
                    ++ [ ./patches/circt-lit-dylib-paths-multicall.patch ];
                  cmakeFlags = o.cmakeFlags ++ [
                    "-DCIRCT_TOOLS_DRIVER=ON"
                    # Executables only: fold identical code across the union.
                    "-DCMAKE_EXE_LINKER_FLAGS=-fuse-ld=lld -Wl,--icf=all"
                  ];
                });
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
