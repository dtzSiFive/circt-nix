{ pkgs ? import <nixpkgs> {}, circt-src, llvm-submodule-src }:

let

  mlir-src = pkgs.runCommand "mlir-src" {} ''
    mkdir -p $out
    cp -r ${llvm-submodule-src}/{cmake,mlir} -t $out
  '';

  #mlir-new = (pkgs.llvmPackages_14.mlir.overrideAttrs (o: {
  #  sourceRoot = "mlir-src/mlir";
  #  patches = [ ./mlir-gnu-installdirs.patch ];
  #})).override { monorepoSrc = llvm-submodule-src; };
  # XXX: override monorepoSrc only?
  libllvm-new = pkgs.llvmPackages_14.libllvm.override { monorepoSrc = llvm-submodule-src; };
  mlir-new = pkgs.llvmPackages_14.mlir.overrideAttrs (o: {
    src = mlir-src;
    sourceRoot = "mlir-src/mlir";
    patches = [ ./mlir-gnu-installdirs.patch ];
    buildInputs = [ pkgs.vulkan-loader pkgs.vulkan-headers libllvm-new ];
  });
  llvm-cmake = pkgs.runCommand "llvm-cmake-patched" {} ''
    mkdir -p $out/lib
    cp -r ${libllvm-new}/lib/cmake $out/lib
    for x in $out/lib/cmake/llvm/{TableGen,AddLLVM}.cmake; do
      substituteInPlace "$x" --replace 'DESTINATION ''${LLVM_INSTALL_TOOLS_DIR}' 'DESTINATION ''${CMAKE_INSTALL_BINDIR}'
  '';

  ##
  # Plan:
  # Fetch circt tree all-at-once.
  # * don't need all of the pinned llvm-project (probably), maybe drop what's not needed post-unpack
  # Build llvm, mlir, using nix bits but pinned source
  # Build mlir separately?

  # Build circt separately (per instructions)

  # circt (source) as flake input? >:D

  #-----------------

  # Upstream mlir into nixpkgs
  # - Add to git variant (?), if that helps here (easy to set git hash?)
  # Here, override llvm source to our submodule and build MLIR from local submodule as well
  # If nix flakes+submodules are pain, just bake llvm commit as flake input, bump manually for now

  #mlir-llvm = llvm: llvm.overrideAttrs(o: {
  #  src = "${circt-src}/llvm";
  #  sourceRoot = "llvm/llvm";
  #  cmakeFlags = o.cmakeFlags ++ [
  #    "-DLLVM_ENABLE_ASSERTIONS=ON"
  #    "-DLLVM_ENABLE_PROJECTS=mlir"
  #  ];

  #  postPatch = o.postPatch or "" + ''
  #    # create with sane permissions
  #    mkdir -p build/lib/cmake/mlir
  #    echo "-------"
  #    pwd
  #    ls -la
  #    chmod u+rw -R ..
  #  '';
  #  #prePatch = o.prePatch or "" + ''
  #  #  pwd
  #  #  ls
  #  #  echo ------
  #  #  find .
  #  #'';
  #});
  #llvmTest = mlir-llvm pkgs.llvmPackages_14.llvm;
  circt = pkgs.stdenv.mkDerivation {
    pname = "circt";
    version = "0.0.8-git"; # TODO: better
    nativeBuildInputs = with pkgs; [ cmake ];
    buildInputs = [ mlir-new libllvm-new ];
    src = circt-src;

    patches = [
      ./no-deps-mlir-utils.patch
      ./0001-mlir-tblgen.patch
    ];
    postPatch = ''
      substituteInPlace CMakeLists.txt --replace @MLIR_TABLEGEN_EXE@ "${mlir-new}/bin/mlir-tblgen"
    '';
    cmakeFlags = [
      "-DLLVM_TOOLS_INSTALL_DIR=${placeholder "out"}/bin"
    ];
    #cmakeFlags = [
    #  "-DMLIR_DIR=${mlir-new.dev}/lib/cmake/mlir"
    #  "-DMLIR_TABLEGEN_EXE=${mlir-new}/bin/mlir-tblgen"
    #  "-DMLIR_TABLEGEN=${mlir-new}/bin/mlir-tblgen"
    #];

    #postPatch = ''
    #  substituteInPlace CMakeLists.txt \
    #    --replace 'set(MLIR_TABLEGEN_EXE $<TARGET_FILE:mlir-tblgen>)' \
    #              'set(MLIR_TABLEGEN_EXE "ASDF")'
    #'';

    # enableParallelBuilding = false;
  };

in

#  llvmTest

circt
