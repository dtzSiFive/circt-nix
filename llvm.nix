{ runCommand, llvmPackages, llvm-submodule-src }:
let
  monorepoSrc = llvm-submodule-src;
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
    mlir = pkgs.llvmPackages_14.mlir.override {
      inherit monorepoSrc libllvm version;
    };
    libclang = pkgs.llvmPackages_14.libclang.override {
      inherit monorepoSrc libllvm version;
    };
  };
in
  newPkgs
