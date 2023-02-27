{
  mustangPkgs,
  chooseRustPlatform,
  findDep,
  buildRustCrateForPkgsPathMustang,
}: path: let
  sysroot = mustangPkgs.callPackage ./Cargo.nix {
    defaultCrateOverrides = mustangPkgs.defaultCrateOverrides;
    buildRustCrateForPkgs = pkgs: let
      mkRustSrc = p:
        (chooseRustPlatform path pkgs).rustLibSrc + p;
    in
      (buildRustCrateForPkgsPathMustang path pkgs).override {
        defaultCrateOverrides =
          pkgs.defaultCrateOverrides
          // {
            core = attrs: {
              src = mkRustSrc "/core";
              # These are for crates that have relative paths in their Cargo.toml
              postUnpack = ''
                ln -s ${mkRustSrc "/stdarch"} $sourceRoot/..
                ln -s ${mkRustSrc "/portable-simd"} $sourceRoot/..
              '';
            };
            alloc = attrs: {src = mkRustSrc "/alloc";};
            std = attrs: {
              src = mkRustSrc "/std";
              # These are for the include_str macros
              postUnpack = ''
                ln -s ${mkRustSrc "/stdarch"} $sourceRoot/..
                ln -s ${mkRustSrc "/portable-simd"} $sourceRoot/..
                ln -s ${mkRustSrc "/backtrace"} $sourceRoot/..
                ln -s ${mkRustSrc "/core"} $sourceRoot/..
              '';
            };
            rustc-std-workspace-core = attrs: {src = mkRustSrc "/rustc-std-workspace-core";};
            rustc-std-workspace-alloc = attrs: {src = mkRustSrc "/rustc-std-workspace-alloc";};
            rustc-std-workspace-std = attrs: {src = mkRustSrc "/rustc-std-workspace-std";};
            panic_abort = attrs: {src = mkRustSrc "/panic_abort";};
            proc_macro = attrs: {src = mkRustSrc "/proc_macro";};
            panic_unwind = attrs: {src = mkRustSrc "/panic_unwind";};
            std_detect = attrs: {src = mkRustSrc "/stdarch/crates/std_detect";};
            unwind = attrs: {src = mkRustSrc "/unwind";};
            test = attrs: {
              src = mkRustSrc "/test";

              postUnpack = ''
                ln -s ${mkRustSrc "/panic_unwind"} $sourceRoot/..
              '';
            };
          };
      };
  };

  deps = sysroot.rootCrate.build.dependencies;
in {
  mustangCore = findDep deps "core";
  mustangCompilerBuiltins = findDep deps "compiler_builtins";
  mustangAlloc = findDep deps "alloc";
  mustangStd = findDep deps "std";
  mustangUnwind = findDep deps "unwind";
  mustangTest = findDep deps "test";
  mustangPanicUnwind = findDep deps "panic_unwind";
  sysrootCI = sysroot.rootCrate.build;
}
