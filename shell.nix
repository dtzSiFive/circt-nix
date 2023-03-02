{ pkgs ? import <nixpkgs> {}
, llvmPkgs ? pkgs.llvmPackages_15
, withOrTools ? false # pkgs.stdenv.hostPlatform.isLinux
}:
#{ pkgs ? import (fetchTarball channel:nixos-21.11) {} }:

# Use with (nix-)direnv to automatically get dev env when cd to circt src:
# $ ln -s $PWD/shell.nix /path/to/circt-src/shell.nix
# $ echo "use nix" >> /path/to/circt-src/.envrc
#
# Or with flakes (and circt in registry):
# $ echo "use flake circt" >> /path/to/circt-src/.envrc

with pkgs;

let
  # (from firefox's nix expression, FWIW)
  theStdenv = overrideCC llvmPkgs.stdenv (llvmPkgs.stdenv.cc.override {
    inherit (llvmPkgs) bintools;
  });
  python = python3.withPackages (ps: [ ps.psutil ps.pycapnp ps.numpy ps.pybind11 ps.pyyaml ]);
in
(mkShell.override { stdenv = theStdenv; }) {
  nativeBuildInputs = [
    (clang-tools.override { llvmPackages = llvmPkgs; })
    theStdenv.cc.cc.python # git-clang-format
    cmakeCurses # cmake
    pkg-config
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
  ] ++ lib.optionals (withOrTools) [
    or-tools bzip2 cbc eigen glpk re2
  ];
}
