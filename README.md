# circt-nix

[![Build](https://github.com/dtzSiFive/circt-nix/actions/workflows/cachix.yml/badge.svg)](https://github.com/dtzSiFive/circt-nix/actions/workflows/cachix.yml)
[![Cachix Cache][cachix-cache-shield]][cachix-cache]

[cachix-cache]: https://dtz-circt.cachix.org
[cachix-cache-shield]: https://img.shields.io/badge/cachix-dtz--circt-blue.svg

Package LLVM, MLIR, and CIRCT and related projects using nix + flakes.

Available packages:

* circt - [CIRCT](https://circt.llvm.org)
* mlir - MLIR (built using LLVM version pinned by CIRCT)
* slang - [SystemVerilog compiler and language services](https://sv-lang.com)

For a list of all outputs, see `nix flake show circt` (after adding to registry, see below).
Only x86_64-linux has been tested.

Built with assertions enabled.

## Install

This requires `nix`, preferably with flake support.
Flake support is assumed throughout,
to use without flakes see [Without Flakes](#without-flakes).

Clone repository locally if you would like to make changes to it,
but otherwise no installation required.

### Cachix (use prebuilt paths)

Use the [dtz-circt cachix][cachix-cache] to use prebuilt paths
when available.

Follow the instructions at that link,
or install cachix yourself and run `cachix use dtz-circt`.

## Usage

Either refer to this flake as `github:dtzSiFive/circt-nix`,
or optionally add this to your flake registry for simpler invocations:

```
$ nix registry add circt github:dtzSiFive/circt-nix
```

For brevity's sake, the remaining commands will assume this has been
added to your registry, but if not use the longer reference.

Registry entries can be pinned with `nix registry pin`.

### Build CIRCT

```
$ nix build circt
$ ./result/bin/firtool --help
```

Prebuilt versions may be available via cachix,
but if not (or not using it) this will
build LLVM, MLIR, and CIRCT (separately).

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

See [Without Flakes](#without-flakes).

### Development shell for working on CIRCT

This repo also provides a development shell for work on CIRCT.

To use:

```
$ nix develop circt
```

Or with [nix-direnv](https://github.com/nix-community/nix-direnv):

```
$ echo "use flake circt" >> /path/to/circt-src/.envrc
```

So that the environment is automatically loaded/unloaded when cd'ing to that directory.


### Without Flakes


Compatibility with non-flakes nix is provided for use with non-flakes tools,
such as with `nix-env`.

Generally speaking, point the command at this repository usually with:
```
-f https://github.com/dtzSiFive/circt-nix/archive/master.tar.gz
```

#### Install to profile: nix-env

```
$ nix-env -f https://github.com/dtzSiFive/circt-nix/archive/master.tar.gz -iA default
```

#### nix-build

```
$ nix-build https://github.com/dtzSiFive/circt-nix/archive/master.tar.gz -A default
```

## Maintainer

[Will Dietz](will.dietz@sifive.com)
