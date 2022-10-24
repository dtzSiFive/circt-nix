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
    # Fix broken CMakeLists.txt :(
    (fetchpatch {
       url = "https://github.com/llvm/llvm-project/commit/e78247112ac2599bd682e16429bfceada4ac803d.patch";
       sha256 = "sha256-cbtsu8TXN9vKoPo3O2vxZq/qWsY3Jx2lxqbm8tCXSVY=";
    })
    (fetchpatch {
       url = "https://github.com/llvm/llvm-project/commit/d8cb5d3c6e1883166d8d2a8dbb4b497a8fd37f4a.patch";
       sha256 = "sha256-foVFlZI0dM+27yPQW0RQFovd0/7kUxhxd/iRHilaoys=";
    })
    # ./patches/mlir-add-include-to-path.patch
  ];
  # Version string:
  mkVer = src:
    let
      date = builtins.substring 0 8 (src.lastModifiedDate or src.lastModified or "19700101");
      rev = src.shortRev or "dirty";
    in
      "${date}_${rev}";
  version = mkVer llvm-submodule-src;

  addAsserts = p: if !enableAssertions then p else p.overrideAttrs(o: {
    cmakeFlags = o.cmakeFlags or [] ++ [ "-DLLVM_ENABLE_ASSERTIONS=ON" ];
  });
  overrideLLVMPkg = p: args: p.override ({ inherit monorepoSrc version; } // args);
  overridePkg = p: overrideLLVMPkg (addAsserts p);

in rec {
  libllvm = overridePkg llvmPackages.libllvm { };
  mlir = overridePkg llvmPackages.mlir { inherit libllvm; monorepoSrc = patchsrc monorepoSrc [ ./patches/mlir-add-include-to-path.patch ]; };
  libclang = overridePkg llvmPackages.libclang { inherit libllvm; };

  # Split out needed unittest bits, required by sub-projects.
  llvmUtilsSrc = runCommand "llvm-src-for-unittests" {} ''
    mkdir -p "$out/utils"
    cp -r ${monorepoSrc}/llvm/utils/unittest -t "$out/utils"
  '';
}
