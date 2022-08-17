{ pkgs ? import <nixpkgs> {}}:
#{ pkgs ? import (fetchTarball channel:nixos-21.11) {} }:

with pkgs;

let
  llvmPkgs = llvmPackages_14;
  # (from firefox's nix expression, FWIW)
  theStdenv = overrideCC llvmPkgs.stdenv (llvmPkgs.stdenv.cc.override {
    inherit (llvmPkgs) bintools;
  });
  python = python3.withPackages (ps: [ ps.psutil ps.pycapnp /* ps.numpy */ /* for MLIR python bindings */ ]);
in
(mkShell.override { stdenv = theStdenv; }) {
  nativeBuildInputs = [
    (clang-tools.override { llvmPackages = llvmPkgs; })
    theStdenv.cc.cc.python # git-clang-format
    cmakeCurses # cmake
    python
    which
    ninja

    doxygen
    graphviz #-nox
  ];
  buildInputs = [
    libxml2 libffi ncurses zlib
    libedit
    capnproto verilator
    zstd
  ];
}
