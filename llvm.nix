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
    libllvm-unpatched = (llvmPackages.libllvm.override { inherit monorepoSrc version; }).overrideAttrs(o: {
      cmakeFlags = o.cmakeFlags or [] ++ [ "-DLLVM_ENABLE_ASSERTIONS=ON" ];
    });
    # Patch up installed cmake files: projects using LLVM cannot and should not have to install their binaries
    # into the same prefix as LLVM was built with.
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
    mlir = (llvmPackages.mlir.override {
      inherit monorepoSrc libllvm version;
    }).overrideAttrs (o: 
      let bins = [ "mlir-pdll-lsp-server" "tblgen-lsp-server" ]; in {
      postPatch = ''
        # Patch around check for being built native (maybe because not built w/LLVM?)
        # TODO: Find a way to fix this check (instead of forcing it) for the standalone case
        for x in lib/CAPI/CMakeLists.txt python/CMakeLists.txt test/CAPI/CMakeLists.txt test/CMakeLists.txt tools/CMakeLists.txt unittests/CMakeLists.txt; do
          substituteInPlace "$x" \
            --replace 'if(TARGET ''${LLVM_NATIVE_ARCH})' 'if (1)'
        done
        for x in test/CMakeLists.txt lib/ExecutionEngine/CMakeLists.txt; do
          substituteInPlace "$x" \
              --replace 'if(NOT TARGET ''${LLVM_NATIVE_ARCH})' 'if (0)'
        done
      '';

      # Also build/install 'bins' (not included in base expression, they weren't in last release).
      postBuild = ''
        make ${lib.concatStringsSep " " bins} -j$NIX_BUILD_CORES -l$NIX_BUILD_CORES
      '' + o.postBuild;

      postInstall = ''
        install -Dm755 -t $out/bin ${lib.concatMapStringsSep " " (x: "bin/${x}") bins}
      '' + o.postInstall;

      cmakeFlags = o.cmakeFlags or [] ++ [ "-DLLVM_ENABLE_ASSERTIONS=ON" ];
    });
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
