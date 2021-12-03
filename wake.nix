{ pkgs ? import <nixpkgs> { } }:
with pkgs;

mkShell {
  pname = "testing";
}

