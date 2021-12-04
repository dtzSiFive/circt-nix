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
  };

  outputs = { self, nixpkgs, flake-utils, wake-src }:
    flake-utils.lib.eachDefaultSystem
      (system:
        let pkgs = nixpkgs.legacyPackages.${system}; in
        rec {
          #devShell = import ./shell.nix { inherit pkgs; };
          packages = flake-utils.lib.flattenTree {
            hello = pkgs.hello;
            wake = pkgs.callPackage ./wake.nix { inherit wake-src; };
          };
          # defaultPackage = packages.foo;
          defaultPackage = packages.hello;

          #defaultPackage = import ./build.nix { inherit self pkgs; };
        }
      );
}
