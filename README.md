# circt-nix

Package LLVM, MLIR, and CIRCT using nix + flakes.

Available packages:

* circt - [CIRCT](https://circt.llvm.org)
* mlir - MLIR (built using LLVM version pinned by CIRCT)

For a list of all outputs, see `nix flake show circt` (after adding to registry, see below).
Only x86_64-linux has been tested.

## Install

This requires `nix`, preferably with flake support.
Flake support is assumed throughout,
to use without flakes see [Without Flakes](#without-flakes).

Clone repository locally if would like to make changes to it,
but otherwise no installation required.

## Usage

Either refer to this flake as `github:dtzSiFive/circt`,
or optionally add this to your flake registry for simpler invocations:

```
$ nix registry add circt github:dtzSiFive/circt
```

For brevity's sake, the remaining commands will assume this has been
added to your registry, but if not use the longer reference.

Registry entries can be pinned with `nix registry pin`.

### Build CIRCT

$ nix build circt
$ ./result/bin/firtool --help

In the future, prebuilt versions may be available via cachix,
but for now this will build LLVM, MLIR, and CIRCT.

### Install to profile

#### nix profile

`nix profile` is experimental, but works natively with flakes.

In addition to simpler installation procedure (of CIRCT),
since `nix profile` tracks installation origin details,
it's easy to upgrade your CIRCT installation
when updates to this repository are made.

```
$ nix profile install circt
```

#### nix-env

See the next section.


### Without Flakes


Compatibility with non-flakes nix is provided for use with non-flakes tools,
such as with `nix-env`.

Generally speaking, point the command at this repository usually with:
```
-f https://github.com/dtzSiFive/circt/archive/master.tar.gz
```

#### Install to profile: nix-env

```
$ nix-env -f https://github.com/dtzSiFive/circt/archive/master.tar.gz -iA circt
```

#### nix-build

```
$ nix-build -f https://github.com/dtzSiFive/circt/archive/master.tar.gz -A circt
```

## Maintainer

(Will Dietz)[will.dietz@sifive.com]
