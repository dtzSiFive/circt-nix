{
  description = "circt-y things";

  inputs.flake-utils.url = "github:numtide/flake-utils";
  outputs = { self, nixpkgs }: {

    packages.x86_64-linux.hello = nixpkgs.legacyPackages.x86_64-linux.hello;

    defaultPackage.x86_64-linux = self.packages.x86_64-linux.hello;

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem
      (system:
        let pkgs = nixpkgs.legacyPackages.${system}; in
        rec {
          #devShell = import ./shell.nix { inherit pkgs; };
          packages = flake-utils.lib.flattenTree {
            hello = pkgs.hello;
          };
          # defaultPackage = packages.foo;

          #defaultPackage = import ./build.nix { inherit self pkgs; };
        }
      );

  };
}
