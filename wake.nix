{ pkgs ? import <nixpkgs> { } }:
with pkgs;

stdenv.mkDerivation {
  pname = "wake";
  version = "0.24.0"; # from flake input?
}

