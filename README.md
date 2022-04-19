# circt-nix

Package LLVM, MLIR, circt, and related projects using nix + flakes.

## Install

This requires `nix` with flake support.

Clone repository locally if would like to make changes to it,
but otherwise no installation required.

### (Optional) Add to flake registry

```
$ nix registry add circt github:dtzSiFive/circt
```

## Usage

```
$ nix build github:dtzSiFive/circt
```

OR (if registered as flake)

```
$ nix build circt
```

## Maintainer

Will Dietz, w@wdtz.org.
