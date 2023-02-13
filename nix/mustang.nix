{mustangPkgs}: let
  buildRustCrateForMustang = {
    buildRustCrate,
    rustc,
    cargo,
  }:
    buildRustCrate.override {
      stdenv = mustangPkgs.stdenv;
      inherit rustc cargo;
    };
in {
  inherit buildRustCrateForMustang;
}
