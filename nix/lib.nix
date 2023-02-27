{lib}: rec {
  findDep = deps: crate:
    lib.findFirst
    (p: lib.hasPrefix "rust_${crate}" p.name)
    (builtins.throw "no crate ${crate}!")
    deps;

  # Provide a list of functions that take `pkgs: args:`
  # This is passed into `buildRustCrateForPkgs
  # Calls each function with pkgs.
  # Then right folds the list of functions calling them with args,
  # and the default attrs are nul
  combineWrappers = funs: pkgs: args:
    lib.foldr (f: a: f a) args (builtins.map (f: f pkgs) funs);

  vendorIsMustang = pkgs: platform:
    pkgs.rust.lib.toTargetVendor platform == "mustang";

  chooseRustPlatform = path: pkgs:
    if vendorIsMustang pkgs pkgs.stdenv.hostPlatform
    then pkgs.buildPackages.buildPackages.${path}
    else pkgs.buildPackages.${path};

  buildRustCrateForPkgsPathMustang = path: pkgs: let
    platform = chooseRustPlatform path pkgs;
  in
    pkgs.buildRustCrate.override {
      inherit (platform) rustc cargo;
    };

  mustangTargets = pkgs:
    pkgs.stdenv.mkDerivation {
      name = "mustang-target-specs";
      src = pkgs.fetchgit {
        url = "ssh://git@github.com/jordanisaacs/mustang";
        rev = "928ea39da900b793690d0c38c8b79d20e7a5b92f";
        sha256 = "1c8axd4mzficf6h3jg1gid2mjrf52xfphv1zy9sdhs4pqdbc3q73";
      };
      installPhase = ''
        mkdir $out
        cp mustang/target-specs/* $out
      '';
    };

  rustcCross = {
    mustangTarget,
    pkgs,
  }: {
    config = mustangTarget;
    platform = builtins.fromJSON (builtins.readFile "${mustangTargets pkgs}/${mustangTarget}.json");
  };

  buildSysroot = path: mustangPkgs:
    import ./sysroot/sysroot.nix {inherit mustangPkgs chooseRustPlatform findDep buildRustCrateForPkgsPathMustang;} path;
}
