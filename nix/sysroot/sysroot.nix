{
  lib,
  callPackage,
  defaultCrateOverrides,
  buildRustCrateForMustang,
  buildRustCrate,
  rustc,
  cargo,
  rustLibSrc,
}: let
  sysroot = callPackage ./Cargo.nix {
    defaultCrateOverrides = defaultCrateOverrides;
    buildRustCrateForPkgs = pkgs:
      (buildRustCrateForMustang {inherit rustc cargo buildRustCrate;}).override {
        defaultCrateOverrides = let
          rustLib = p: rustLibSrc + p;
        in
          pkgs.defaultCrateOverrides
          // {
            core = attrs: {
              src = rustLib "/core";
              # These are for crates that have relative paths in their Cargo.toml
              postUnpack = ''
                ln -s ${rustLib "/stdarch"} $sourceRoot/..
                ln -s ${rustLib "/portable-simd"} $sourceRoot/..
              '';
            };
            alloc = attrs: {src = rustLib "/alloc";};
            std = attrs: {
              src = rustLib "/std";
              # These are for the include_str macros
              postUnpack = ''
                ln -s ${rustLib "/stdarch"} $sourceRoot/..
                ln -s ${rustLib "/portable-simd"} $sourceRoot/..
                ln -s ${rustLib "/backtrace"} $sourceRoot/..
                ln -s ${rustLib "/core"} $sourceRoot/..
              '';
            };
            rustc-std-workspace-core = attrs: {src = rustLib "/rustc-std-workspace-core";};
            rustc-std-workspace-alloc = attrs: {src = rustLib "/rustc-std-workspace-alloc";};
            rustc-std-workspace-std = attrs: {src = rustLib "/rustc-std-workspace-std";};
            panic_abort = attrs: {src = rustLib "/panic_abort";};
            std_detect = attrs: {src = rustLib "/stdarch/crates/std_detect";};
            unwind = attrs: {src = rustLib "/unwind";};
          };
      };
  };

  findDep = deps: crate:
    lib.findFirst
    (p: lib.hasPrefix "rust_${crate}" p.name)
    (builtins.throw "no crate ${crate}!")
    deps;

  deps = sysroot.rootCrate.build.dependencies;
  mustangCore = findDep deps "core";
  mustangCompilerBuiltins = findDep deps "compiler_builtins";
  mustangStd = findDep deps "std";
  sysrootCI = sysroot.rootCrate.build;
in {
  inherit sysroot sysrootCI mustangCompilerBuiltins mustangCore mustangStd;
}
