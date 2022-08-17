{ lib, fetchpatch, applyPatches, runCommand
, llvm-submodule-src 
, llvmPackages
, enableAssertions ? true
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
  ];
  # Version string:
  version = "git-${llvm-submodule-src.shortRev}";

  addAsserts = p: if !enableAssertions then p else p.overrideAttrs(o: {
    cmakeFlags = o.cmakeFlags or [] ++ [ "-DLLVM_ENABLE_ASSERTIONS=ON" ];
  });
  overrideLLVMPkg = p: args: p.override ({ inherit monorepoSrc version; } // args);
  overridePkg = p: overrideLLVMPkg (addAsserts p);

in rec {
  libllvm = overridePkg llvmPackages.libllvm { };
  mlir = overridePkg llvmPackages.mlir { inherit libllvm; };
  libclang = overridePkg llvmPackages.libclang { inherit libllvm; };

  # Split out needed unittest bits, required by sub-projects.
  llvmUtilsSrc = runCommand "llvm-src-for-unittests" {} ''
    mkdir -p "$out/utils"
    cp -r ${monorepoSrc}/llvm/utils/unittest -t "$out/utils"
  '';
}
