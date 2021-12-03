{
  description = "circt-y things";

  inputs.flake-utils.url = "github:numtide/flake-utils";

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem
      (system:
        let pkgs = nixpkgs.legacyPackages.${system}; in
        rec {
          #devShell = import ./shell.nix { inherit pkgs; };
          packages = flake-utils.lib.flattenTree {
            hello = pkgs.hello;
            wake = import ./wake.nix { inherit pkgs /* wake */; };
          };
          # defaultPackage = packages.foo;
          defaultPackage = packages.hello;

          #defaultPackage = import ./build.nix { inherit self pkgs; };
        }
      );
}
