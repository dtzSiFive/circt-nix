{ pkgs ? import <nixpkgs> {}
, llvmPkgs ? pkgs.llvmPackages_19
, withOrTools ? false # pkgs.stdenv.hostPlatform.isLinux
, withZ3 ? true
, withVerilator ? !pkgs.stdenv.hostPlatform.isDarwin
}:
#{ pkgs ? import (fetchTarball channel:nixos-24.11) {} }:

# Use with (nix-)direnv to automatically get dev env when cd to circt src:
# $ ln -s $PWD/shell.nix /path/to/circt-src/shell.nix
# $ echo "use nix" >> /path/to/circt-src/.envrc
#
# Or with flakes (and circt in registry):
# $ echo "use flake circt" >> /path/to/circt-src/.envrc

with pkgs;

let
  # (combined with stdenv from firefox's nix expression, FWIW, don't override on Darwin.)
  # TODO: Investigate best way to do this now.
  theStdenv = if pkgs.stdenv.hostPlatform.isDarwin then llvmPkgs.stdenv else overrideCC llvmPkgs.stdenv (llvmPkgs.stdenv.cc.override {
    inherit (llvmPkgs) bintools;
  });
  python = python3.withPackages (ps: [ ps.psutil ps.numpy ps.pybind11 ps.pyyaml ]);
in
(mkShell.override { stdenv = theStdenv; }) {
  nativeBuildInputs = [
    llvmPkgs.clang-tools
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
    grpc
    zstd
  ] ++ lib.optionals (withOrTools) [
    or-tools bzip2 cbc eigen glpk re2
  ] ++ lib.optional (withVerilator) verilator
    ++ lib.optional (withZ3) z3;
}
