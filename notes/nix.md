# Nix notes

This covers everything Nix/Nixpkgs/Nixos related. Packaging, CI, etc.

# Packaging Software

## Status of lang2nix approaches

[link](https://discourse.nixos.org/t/status-of-lang2nix-approaches/14477?u=snowytrees)

## rust2nix Comparisons

[link](https://discourse.nixos.org/t/cargo2nix-dramatically-simpler-rust-inside-nix/9334/2?u=snowytrees)

`buildRustCrate` + `crate2nix` is most Nix-native approach. Each crate and its dependent is a separate Nix derivation + output path. Crates only re-compiled when necessary. Output paths can be shared between different rust projects.

## sysroot

Using a sysroot to cross compile `core` and `std`. rustc can cross compile so do not need to build rust itself for the target platform. The sysroot is just a crate that depends directly on core, std, and compiler_builtins (using paths). This lets us generate a Cargo.lock which in turn can generate a Cargo.nix. Now our "core" and "std" dependencies are not using the prebuilt ones, but instead our custom cross compiled version.

For mustang we do not care about cross compiling any other dependencies
the passed `rustc` and `cargo` commands (should be the build)

## build-rust-crate

Target is set in `build-crate.nix` based on the stdenv [source](https://github.com/NixOS/nixpkgs/blob/refs%2Fheads%2Fnixpkgs-unstable/pkgs/build-support/rust/build-rust-crate/build-crate.nix#L24).

## Cross Compilation - nix.dev

[link](https://nix.dev/tutorials/cross-compilation)

Build platform: Where executable is built

Host Platform: where compiled executable runs

Target platform (is relevant for compilers): build compiler on *build platform*, run it on *host platform*, run final executable on *target platform*

There are a set of predefined host platforms in `pkgsCross` - retrieve platform string with `pkgsCross.<platform>.stdenv.hostPlatform.config`

## Cross Compilation - nix manual

[link](https://nixos.org/manual/nixpkgs/stable/#chap-cross)

## stdenv/top-level/systems

[pkgs/stdenv/default.nix](https://github.com/NixOS/nixpkgs/blob/refs%2Fheads%2Fnixpkgs-unstable/pkgs/stdenv/default.nix)
* Returns the correct bootstrapping function list based on the system (eg `cross`, `linux`, etc)
* Functions are defined in their respect stdenv folder

[Cross System function list](https://github.com/NixOS/nixpkgs/blob/refs%2Fheads%2Fnixpkgs-unstable/pkgs/stdenv/cross/default.nix)
* First function builds the local system. Uses the bootstrapping functions of the local system except for the last one (constructing the final stdenv).
* That last function which constructs the final stdenv is constructed with `allowCustomOverrides` to change the built-time dependencies
* Then tool packages are built, overrides local packages by setting `targetPlatform = crossSystem`
* Then the runtime packages are overriden. Setting the `hostPlatform` and `targetPlatform` to the `crossSystem`

[pkgs/stdenv/adapters.nix](https://sourcegraph.com/github.com/NixOS/nixpkgs@refs/heads/nixpkgs-unstable/-/blob/pkgs/stdenv/adapters.nix)
* Provides a variety of helper functions for taking a stdenv & returning a new stdenv with different behavior

[pkgs/stdenv/booter.nix]()
* Called from the `top-level/default.nix`
* Returns a single function that calls the list of stage functions returned by `stdenv/default.nix`

[pkgs/top-level/default.nix](https://github.com/NixOS/nixpkgs/blob/6d87734c880d704f6ee13e5c0fe835b98918c34e/pkgs/top-level/default.nix)
* [First](https://github.com/NixOS/nixpkgs/blob/6d87734c880d704f6ee13e5c0fe835b98918c34e/pkgs/top-level/default.nix#L61) elaborates `localSystem` and `crossSystem` into full systems ([elaborate function](https://github.com/NixOS/nixpkgs/blob/6d87734c880d704f6ee13e5c0fe835b98918c34e/lib/systems/default.nix#L25))
* [Second](https://github.com/NixOS/nixpkgs/blob/6d87734c880d704f6ee13e5c0fe835b98918c34e/pkgs/top-level/default.nix#L72) loads in the nixpkgs config (can be either function or just attrset) and evaluates it (see [module definition](https://github.com/NixOS/nixpkgs/blob/6d87734c880d704f6ee13e5c0fe835b98918c34e/pkgs/top-level/config.nix) both config and config function)
* [First](https://github.com/NixOS/nixpkgs/blob/refs%2Fheads%2Fnixpkgs-unstable/pkgs/top-level/default.nix#L123) retrieves the boot function by just importing `booter.nix`
* [Second](https://github.com/NixOS/nixpkgs/blob/6d87734c880d704f6ee13e5c0fe835b98918c34e/pkgs/top-level/default.nix#L125) retrieves the stages by just calling `stdenv/default.nix`

## crate2nix Cross Compilation

rustc can cross compile already, so do not need to bootstrap the compiler for the host platform. Only need to bootstrap the core/std libraries. Thus can use the existing toolchain we have (either through nixpkgs or an overlay, eg. oxalica's rust-overlay). Therefore, we are going to override the `buildRustCrate` function to always make sure we are never attempting to compile the compiler. This is done by checking the `hostPlatform` of the pkgs being used to compile the rust crate:

```nix
{
vendorIsMustang = pkgs: platform:
  pkgs.rust.lib.toTargetVendor platform == "mustang";

chooseRustPlatform = path: pkgs:
  if vendorIsMustang pkgs pkgs.stdenv.hostPlatform
  # going up stages to ensure the compiler isn't cross compiled
  then pkgs.buildPackages.buildPackages.${path}
  else pkgs.buildPackages.${path};

buildRustCrateForPkgsPathMustang = path: pkgs: let
  platform = chooseRustPlatform path pkgs;
in
  pkgs.buildRustCrate.override {
    inherit (platform) rustc cargo;
  };
}
```

It works because in the generated `Cargo.nix`, build dependencies and proc macros pass `pkgs.buildPackages` rather than `pkgs` into the `buildRustCrateForPkgs` function. See [here](https://github.com/kolloch/crate2nix/blob/c158203fb0ff6684c35601824ff9f3b78e4dd4ed/crate2nix/templates/nix/crate2nix/default.nix#L263).

Now that you have a function that can compile `core`, `std`, etc. We need to create the sysroot that actually does that. The goal is to get a `Cargo.nix` file that can build our dependenices. We do this through the [update-lockfile.sh](../nix/sysroot/update-lockfile.sh) script. It uses the [cargo.py](../nix/sysroot/cargo.py) script to generate a temporary `Cargo.toml` file which specifies `std`, `core`, etc with paths pointing to our nix provided toolchain source. Then it generates a lock file and calls `crate2nix generate`. However, this `Cargo.nix` file is pointing to absolute nix store paths. So our [derivation](../nix/sysroot/sysroot-cargo.nix) substitutes those absolute paths with the actual nix store paths (but due to how the file was generated they should be the same).

Now that you have a derivation that provides your sysroot, you can compile a package. In addition to using your special build function:

```nix
buildRustCrateForPkgs = pkgs: pkgs.buildRustCrateForPkgsPathMustang path pkgs;
```

you need to override the sysroot dependencies, but only for your non-build dependencies. Thus we use a `combineWrapper` function that lets you override the arguments passed to `buildRustCrate`:

```nix
combineWrappers = funs: pkgs: args:
  lib.foldr (f: a: f a) args (builtins.map (f: f pkgs) funs);
```

This lets you provide a new function that when it sees we are compiling a crate for our cross compilation, to override the dependencies:

```nix
mustangPkgs.callPackage ./Cargo.nix {
  inherit rootFeatures release;
  # Hack to avoid a `.override` that doesn't work when using `combineWrappers
  defaultCrateOverrides = mustangPkgs.defaultCrateOverrides;
  buildRustCrateForPkgs = mustangLib.combineWrappers [
    (pkgs: mustangLib.buildRustCrateForPkgsPathMustang path pkgs)
    (pkgs: args: let
      isMustang = mustangLib.vendorIsMustang pkgs pkgs.stdenv.hostPlatform;
    in
      args
      // pkgs.lib.optionalAttrs isMustang {
        dependencies =
          (map (d: d // {stdlib = true;}) [
            sysroot.mustangCore
            sysroot.mustangCompilerBuiltins
            sysroot.mustangAlloc
            sysroot.mustangStd
            sysroot.mustangPanicUnwind
            sysroot.mustangTest
          ])
          ++ args.dependencies;
      })
  ];
};
```

Note the hack comment, this is because `crate2nix` will attempt to [override](https://github.com/kolloch/crate2nix/blob/c158203fb0ff6684c35601824ff9f3b78e4dd4ed/crate2nix/templates/nix/crate2nix/default.nix#L203) our `buildRustCrateForPkgs` functions if it isn't set. This would fail due to our wrapper.

Thanks to [alamgu](https://github.com/alamgu/alamgu) as this was based on/deciphered from their source code.

### Relevant Cargo info

**Resolver 2**

[link](https://doc.rust-lang.org/cargo/reference/resolver.html#feature-resolver-version-2)

Defaults to version 2 when edition is 2021. Features enabled on build-dependencies or proc-macros are not unified when same dependencies are used as a normal dependency. Eg proc-macros won't pull in std for your no_std build.

## Understanding Nix's String Context

[link](https://shealevy.com/blog/2018/08/05/understanding-nixs-string-context/)

> Investigated this when encountering stirng context errors with crate2nix

Nix tracks the dependency information is associated with strings themselves. Stored as metadata known as **string context**

# CI/CD on Nix

## Hydra

[manual](https://hydra.nixos.org/build/196107287/download/1/hydra/installation.html)

[How to Use Hydra as your Deployment Source of Truth](https://determinate.systems/posts/hydra-deployment-source-of-truth)

## Alternatives

[A nix-native CI setup with buildbot](https://discourse.nixos.org/t/a-nix-native-ci-setup-with-buildbot/20566?u=snowytrees)

## NixOS Tests

[nixos manual](https://nixos.org/manual/nixos/stable/index.html#sec-writing-nixos-tests)

[How to use nixos for lightweight integration tests](https://www.haskellforall.com/2020/11/how-to-use-nixos-for-lightweight.html)

[Make your QEMU 10 times faster with this one weird trick](https://linus.schreibt.jetzt/posts/qemu-9p-performance.html)

