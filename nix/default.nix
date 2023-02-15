{
  pkgs,
  lib ? pkgs.lib,
  mustangPkgs,
  rustc,
  cargo,
  rustLibSrc,
}: let
  mustangLib = pkgs.callPackage ./lib.nix {inherit lib;};
  mustangHelpers = import ./mustang.nix {inherit mustangPkgs;};
  sysrootLib = pkgs.callPackage ./sysroot/sysroot.nix {
    inherit rustc cargo rustLibSrc;
    inherit (mustangHelpers) buildRustCrateForMustang;
  };
in {
  inherit (mustangHelpers) buildRustCrateForMustang;
  inherit (mustangLib) combineWrappers findDep;
  inherit (sysrootLib) sysroot sysrootCI mustangCompilerBuiltins mustangCore mustangStd mustangAlloc mustangUnwind mustangTest mustangPanicUnwind;
}
