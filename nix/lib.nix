{lib}: {
  findDep = deps: crate:
    lib.findFirst
    (p: lib.hasPrefix "rust_${crate}" p.name)
    (builtins.throw "no crate ${crate}!")
    deps;

  # Provide a list of functions that take `pkgs: attrs:`
  # This is passed into `buildRustCrateForPkgs
  # Calls each function with pkgs.
  # Then right folds the list of functions calling them with attrs,
  # and the default attrs are nul
  combineWrappers = funs: pkgs: attrs:
    lib.foldr (f: a: f a) attrs (builtins.map (f: f pkgs) funs);

  vendorIsMustang = platform:
    "mustang" == platform.rustc.platform.vendor;
}
