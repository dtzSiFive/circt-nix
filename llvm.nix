{
  lib,
  fetchpatch,
  applyPatches,
  runCommand,
  circtSrc,
  llvmRev,
  llvmPackages,
  enableAssertions ? true,
  hostOnly ? true,
  enableSharedLibraries ? false,
  buildSharedLibs ? false,
  buildLLVMPackages_circt,
}:
let
  # Apply specified patches to 'src', or if none specified just return src
  patchsrc =
    src: patches:
    if patches == [ ] then
      src
    else
      applyPatches {
        inherit src patches;
        name = "llvm-src-patched";
      };

  # The llvm-project checkout bundled as circtSrc's `llvm` submodule
  # (circtSrc is fetched with fetchSubmodules in flake.nix) -- always
  # exactly what the pinned CIRCT release's submodule pin specifies.
  # Wrapped via runCommand (a symlink, not a copy) to give it a proper
  # name+passthru, the same way nixpkgs itself wraps monorepoSrc in
  # pkgs/development/compilers/llvm/common/llvm/default.nix.
  monorepoSrc = patchsrc (
    runCommand "llvm-monorepo-src" {
      passthru = {
        owner = "llvm";
        repo = "llvm-project";
        rev = llvmRev;
      };
    } ''ln -s ${circtSrc}/llvm $out''
  ) [ ];

  release_version = "23.0.0";

  commonExtraCMakeFlags = [
    (lib.cmakeBool "LLVM_BUILD_UTILS" true)
    # For MLIR: Should just have to specify LLVM_LINK_LLVM_DYLIB,
    # set both to avoid attempting linking against libLLVM*.so if not built.
    (lib.cmakeBool "LLVM_BUILD_LLVM_DYLIB" enableSharedLibraries)
    (lib.cmakeBool "LLVM_LINK_LLVM_DYLIB" enableSharedLibraries)
    (lib.cmakeBool "BUILD_SHARED_LIBS" buildSharedLibs)
  ]
  ++ lib.optional enableAssertions (lib.cmakeBool "LLVM_ENABLE_ASSERTIONS" true)
  ++ lib.optional hostOnly "-DLLVM_TARGETS_TO_BUILD=host";

  noCheck =
    p:
    p.overrideAttrs (o: {
      doCheck = false;
    });

  # New LLVM package set using the pinned source. rev/rev-version only
  # feed the reported LLVM version string; nixpkgs' sha256-based fetch of
  # monorepoSrc (pkgs/development/compilers/llvm/common/common-let.nix) is
  # never reached since monorepoSrc is supplied directly, so no sha256
  # field is needed here.
  baseLLVMPkgs = llvmPackages.override {
    inherit monorepoSrc;
    officialRelease = null;
    gitRelease = {
      rev = llvmRev;
      rev-version = "${release_version}-g${builtins.substring 0 8 llvmRev}";
    };
    buildLlvmPackages = buildLLVMPackages_circt;
  };

  # Optionally tweak the build for libllvm and mlir packages.
  llvmPkgs = baseLLVMPkgs.overrideScope (
    selfLLVM: superLLVM: {
      libllvm =
        ((noCheck superLLVM.libllvm).override {
          inherit enableSharedLibraries;
          devExtraCmakeFlags = commonExtraCMakeFlags;
          buildLlvmPackages = buildLLVMPackages_circt;
        }).overrideAttrs
          (old: {
            passthru = (old.passthru or { }) // {
              inherit buildSharedLibs;
            };
            # nixpkgs' cc-wrapper unconditionally injects
            # `-D_LIBCPP_HARDENING_MODE=...` (it's a no-op for our
            # libstdc++ build), but LLVM's own build also defines it
            # explicitly (e.g. for third-party/benchmark), so the two
            # collide as a macro redefinition. That's normally just a
            # warning, but benchmark's `-pedantic-errors` promotes it to
            # a hard error, so disable this hardening flag entirely.
            hardeningDisable = (old.hardeningDisable or [ ]) ++ [
              "libcxxhardeningextensive"
              "libcxxhardeningfast"
            ];
          });
      mlir =
        (superLLVM.mlir.override {
          inherit (selfLLVM) libllvm;
          devExtraCmakeFlags = commonExtraCMakeFlags ++ [
            "-DMLIR_INSTALL_AGGREGATE_OBJECTS=OFF"
          ];
          buildLlvmPackages = buildLLVMPackages_circt;
        }).overrideAttrs
          (old: {
            passthru = (old.passthru or { }) // {
              inherit buildSharedLibs;
            };
          });
    }
  );
in
{
  inherit llvmPkgs;
  # Just a subpath of monorepoSrc, not a copy of it: CIRCT only reads
  # ${LLVM_THIRD_PARTY_DIR}/unittest (for googletest sources), so there's
  # nothing to be gained from materialising it as its own store path.
  # Interpolating keeps the string context, so monorepoSrc is still a
  # build dependency.
  llvm-third-party-src = "${monorepoSrc}/third-party";
}
// llvmPkgs # // tools // libraries
