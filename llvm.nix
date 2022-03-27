{ lib, fetchpatch, runCommand, llvmPackages, llvm-submodule-src }:
let
  patchsrc = src: patches: runCommand "patched-src" {} (''
    cp -r ${src} "$out"
    chmod u+rw -R $out
  '' + lib.concatMapStringsSep "\n" (p: "patch -p1 -i ${p} -d $out") patches);
  monorepoSrc = patchsrc llvm-submodule-src [
  ];
  version = "git-${llvm-submodule-src.shortRev}";
  newPkgs = rec  {
    libllvm-unpatched = llvmPackages.libllvm.override { inherit monorepoSrc version; };
    libllvm = runCommand "llvm-cmake-patched" { outputs = [ "out" "lib" "dev" ]; } ''
      mkdir -p $dev/lib
      cp -r ${libllvm-unpatched.dev}/lib/cmake $dev/lib
      for x in $dev/lib/cmake/llvm/{TableGen,AddLLVM}.cmake; do
        substituteInPlace "$x" --replace 'DESTINATION ''${LLVM_TOOLS_INSTALL_DIR}' 'DESTINATION ''${CMAKE_INSTALL_BINDIR}'
      done
      ln -s ${libllvm-unpatched.dev}/{bin,include,nix-support} $dev/
      ln -s ${libllvm-unpatched.lib} $lib
      ln -s ${libllvm-unpatched.out} $out
    '';
    mlir = llvmPackages.mlir.override {
      inherit monorepoSrc libllvm version;
    };
    libclang = llvmPackages.libclang.override {
      inherit monorepoSrc libllvm version;
    };
    flang = llvmPackages.flang.override {
      inherit monorepoSrc libclang libllvm mlir version;
      # Hack to use our MLIR as build-tools (tblgen), since not doing cross here anyway
      buildLlvmTools = { inherit mlir; };
    };
    llvmUtilsSrc = runCommand "llvm-src-for-unittests" {} ''
      mkdir -p "$out/utils"
      cp -r ${monorepoSrc}/llvm/utils/unittest -t "$out/utils"
    '';
  };
in
  newPkgs
