{ lib, fetchpatch, applyPatches, runCommand
, llvm-submodule-src 
, llvmPackages
, enableAssertions ? true
, hostOnly ? true
, enableSharedLibraries ? false
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

  release_version = "21.0.0";

  addAsserts = p: if !enableAssertions then p else p.overrideAttrs(o: {
    cmakeFlags = o.cmakeFlags or [] ++ [ "-DLLVM_ENABLE_ASSERTIONS=ON" ];
  });
  setTargets = p: if !hostOnly then p else p.overrideAttrs(o: {
    cmakeFlags = o.cmakeFlags or [] ++ [ "-DLLVM_TARGETS_TO_BUILD=host" ];
  });
  buildUtils = p: p.overrideAttrs(o: {
    cmakeFlags = o.cmakeFlags or [] ++ [ "-DLLVM_BUILD_UTILS=ON" ];
  });
  mlirNoAggObjs = p: p.overrideAttrs(o: {
    cmakeFlags = o.cmakeFlags or [] ++ [ "-DMLIR_INSTALL_AGGREGATE_OBJECTS=OFF" ];
  });

  # New LLVM package set using the pinned source.
  buildLLVMPkgs = llvmPackages.override {
    inherit monorepoSrc;
    officialRelease = null;
    gitRelease = {
      rev = llvm-submodule-src.rev or "dirty";
      rev-version = "${release_version}-${version}";
      inherit (llvm-submodule-src) sha256;
    };
  };

  # Hack to use tblgen from this LLVM.
  # Really should come from buildPackages so this works with cross.
  baseLLVMPkgs = buildLLVMPkgs.override { buildLlvmTools = buildLLVMPkgs.tools; };

  # Optionally tweak the build for libllvm and mlir packages.
  tools = baseLLVMPkgs.tools.extend (self: super: {
    libllvm = (setTargets (addAsserts super.libllvm)).override { inherit enableSharedLibraries; };
    mlir = (mlirNoAggObjs (buildUtils (setTargets (addAsserts super.mlir)))).override { inherit (self) libllvm; };
  });
  inherit (baseLLVMPkgs) libraries;

in {
  inherit tools libraries;
  llvm-third-party-src = runCommand "third-party-src" {} ''
    cp -r ${monorepoSrc}/third-party $out
  '';
} // tools // libraries
