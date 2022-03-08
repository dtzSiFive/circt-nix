{
  description = "circt-y things";


  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
    wake-src = {
      type = "github";
      owner = "sifive";
      repo = "wake";
      ref = "v0.24.0";
      flake = false;
    };
    circt-src = {
      type = "git";
      url = "https://github.com/llvm/circt";
      ref = "main";
      flake = false;
      submodules = true;
    };
    #circt-src = {
    #  type = "github";
    #  owner = "llvm";
    #  repo = "circt";
    #  submodules = true;
    #  ref = "main";
    #  flake = false;
    #};
  };

  outputs = { self, nixpkgs, flake-utils, circt-src, wake-src }:
    flake-utils.lib.eachDefaultSystem
      (system:
        let pkgs = nixpkgs.legacyPackages.${system}; in
        rec {
          #devShell = import ./shell.nix { inherit pkgs; };
          packages = flake-utils.lib.flattenTree {
            hello = pkgs.hello;
            wake = pkgs.callPackage ./wake.nix { inherit wake-src; };
            circt = import ./default.nix { inherit pkgs circt-src; };
          };
          # defaultPackage = packages.foo;
          defaultPackage = packages.hello;

          #defaultPackage = import ./build.nix { inherit self pkgs; };
        }
      );
}
