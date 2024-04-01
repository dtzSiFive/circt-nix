{ lib, fetchpatch, applyPatches, runCommand
, llvm-submodule-src 
, llvmPackages
, enableAssertions ? true
, hostOnly ? true
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
  monorepoSrc = patchsrc llvm-submodule-src [
    ./patches/llvm-ppc-git-exception.patch
  ];
  # Version string:
  mkVer = src:
    let
      date = builtins.substring 0 8 (src.lastModifiedDate or src.lastModified or "19700101");
      rev = src.shortRev or "dirty";
    in
      "${date}_${rev}";
  version = mkVer llvm-submodule-src;

  # Needed until upstream "git" matches.
  release_version = "19.0.0";

  addAsserts = p: if !enableAssertions then p else p.overrideAttrs(o: {
    cmakeFlags = o.cmakeFlags or [] ++ [ "-DLLVM_ENABLE_ASSERTIONS=ON" ];
  });
  setTargets = p: if !hostOnly then p else p.overrideAttrs(o: {
    cmakeFlags = o.cmakeFlags or [] ++ [ "-DLLVM_TARGETS_TO_BUILD=host" ];
  });
  installGTest = p: p.overrideAttrs(o: {
    cmakeFlags = o.cmakeFlags or [] ++ [ "-DLLVM_INSTALL_GTEST=ON" ];
  });
  overrideLLVMPkg = p: args: p.override ({ inherit monorepoSrc version; } // args);
  overridePkg = p: overrideLLVMPkg (installGTest (setTargets (addAsserts p)));

in rec {
  libllvm = overridePkg llvmPackages.libllvm {
    inherit release_version;
    enablePolly = false; /* patch doesn't work on our rev */
    enableGoldPlugin = false; # Workaround `ld --help` crash on Darwin in lit.cfg.py.
  };
  mlir = overridePkg llvmPackages.mlir { inherit libllvm; };
  libclang = overridePkg llvmPackages.libclang { inherit libllvm; };
}
