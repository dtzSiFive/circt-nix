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

  # Needed until upstream "git" matches.
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
  overrideLLVMPkg = p: args: p.override ({ inherit monorepoSrc version; } // args);
  overridePkg = p: overrideLLVMPkg (setTargets (addAsserts p));

in rec {
  libllvm = overridePkg llvmPackages.libllvm {
    inherit release_version;
    enablePolly = false; /* patch doesn't work on our rev */
    doCheck = false; # Temporary hack for Darwin AArch64Test cl::opt badness :(
    inherit enableSharedLibraries;
  };
  mlir = overrideLLVMPkg (mlirNoAggObjs (buildUtils (setTargets (addAsserts llvmPackages.mlir)))) { inherit libllvm; };
  libclang = overridePkg llvmPackages.libclang { inherit libllvm; };

  # Split out needed unittest bits, required by sub-projects.
  llvm-third-party-src = runCommand "third-party-src" {} ''
    cp -r ${monorepoSrc}/third-party $out
  '';
}
