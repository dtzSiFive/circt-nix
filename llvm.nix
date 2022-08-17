{ lib, fetchpatch, runCommand, llvmPackages, llvm-submodule-src }:
let
  patchsrc = src: patches:
    if patches == [] then src
    else runCommand "patched-src" {} (''
    cp -r ${src} "$out"
    chmod u+rw -R $out
  '' + lib.concatMapStringsSep "\n" (p: "patch -p1 -i ${p} -d $out") patches);
  monorepoSrc = patchsrc llvm-submodule-src [
  ];
  version = "git-${llvm-submodule-src.shortRev}";
  newPkgs = rec {
    libllvm = (llvmPackages.libllvm.override { inherit monorepoSrc version; }).overrideAttrs(o: {
      cmakeFlags = o.cmakeFlags or [] ++ [ "-DLLVM_ENABLE_ASSERTIONS=ON" ];
    });

    mlir = (llvmPackages.mlir.override {
      inherit monorepoSrc libllvm version;
    }).overrideAttrs (o: {
      cmakeFlags = o.cmakeFlags or [] ++ [ "-DLLVM_ENABLE_ASSERTIONS=ON" ];
    });
    libclang = llvmPackages.libclang.override {
      inherit monorepoSrc libllvm version;
    };
    #flang = llvmPackages.flang.override {
    #  inherit monorepoSrc libclang libllvm mlir version;
    #  # Hack to use our MLIR as build-tools (tblgen), since not doing cross here anyway
    #  buildLlvmTools = { inherit mlir; };
    #};
    llvmUtilsSrc = runCommand "llvm-src-for-unittests" {} ''
      mkdir -p "$out/utils"
      cp -r ${monorepoSrc}/llvm/utils/unittest -t "$out/utils"
    '';
  };
in
  newPkgs
