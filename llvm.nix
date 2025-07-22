{ lib, fetchpatch, applyPatches, runCommand
, llvm-submodule-src 
, llvmPackages
, enableAssertions ? true
, hostOnly ? true
, enableSharedLibraries ? false
, buildLLVMPackages_circt
}:
let
  # Apply specified patches to 'src', or if none specified just return src
  patchsrc = src: patches:
    if patches == [] then src
    else applyPatches {
      inherit src patches;
      name = "llvm-src-${version}-patched";
   };


  # LLVM source to use:
  monorepoSrc = (patchsrc llvm-submodule-src [
  ]) // {
    passthru = {
     owner = "llvm";
     repo = "llvm-project";
     inherit (llvm-submodule-src) rev;
    };
  };
  # Version string:
  mkVer = src:
    let
      date = builtins.substring 0 8 (src.lastModifiedDate or src.lastModified or "19700101");
      rev = src.shortRev or "dirty";
    in
      "${date}_${rev}";
  version = mkVer llvm-submodule-src;

  release_version = "22.0.0";

  commonExtraCMakeFlags = [
    (lib.cmakeBool "LLVM_BUILD_UTILS" true)
    # For MLIR: Should just have to specify LLVM_LINK_LLVM_DYLIB,
    # set both to avoid attempting linking against libLLVM*.so if not built.
    (lib.cmakeBool "LLVM_BUILD_LLVM_DYLIB" enableSharedLibraries)
    (lib.cmakeBool "LLVM_LINK_LLVM_DYLIB" enableSharedLibraries)
  ] ++ lib.optional enableAssertions (lib.cmakeBool "LLVM_ENABLE_ASSERTIONS" true)
    ++ lib.optional hostOnly "-DLLVM_TARGETS_TO_BUILD=host";

  noCheck = p: p.overrideAttrs(o: {
    doCheck = false;
  });

  # New LLVM package set using the pinned source.
  baseLLVMPkgs = llvmPackages.override {
    inherit monorepoSrc;
    officialRelease = null;
    gitRelease = {
      rev = llvm-submodule-src.rev or "dirty";
      rev-version = "${release_version}-${version}";
      inherit (llvm-submodule-src) sha256;
    };
    buildLlvmTools = buildLLVMPackages_circt.tools;
  };

  # Optionally tweak the build for libllvm and mlir packages.
  tools = baseLLVMPkgs.tools.extend (final: prev: {
    libllvm = (noCheck prev.libllvm).override {
      inherit enableSharedLibraries;
      devExtraCmakeFlags = commonExtraCMakeFlags;
    };
    mlir = prev.mlir.override {
      inherit (final) libllvm;
      devExtraCmakeFlags = commonExtraCMakeFlags ++ [
        "-DMLIR_INSTALL_AGGREGATE_OBJECTS=OFF"
      ];
    };
  });
  inherit (baseLLVMPkgs) libraries;

in {
  inherit tools libraries;
  llvm-third-party-src = runCommand "third-party-src" {} ''
    cp -r ${monorepoSrc}/third-party $out
  '';
} // tools // libraries
