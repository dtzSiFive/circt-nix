{ pkgs ? import <nixpkgs> { }, wake-src }:
with pkgs;

stdenv.mkDerivation {
  pname = "wake";
  version = wake-src.shortRev;
}

