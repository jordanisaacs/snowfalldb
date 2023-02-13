{lib}: {
  findDep = deps: crate:
    lib.findFirst
    (p: lib.hasPrefix "rust_${crate}" p.name)
    (builtins.throw "no crate ${crate}!")
    deps;

  combineWrappers = funs: pkgs: args:
    lib.foldr (f: a: f a) args (builtins.map (f: f pkgs) funs);

  vendorIsMustang = platform:
    "mustang" == platform.rustc.platform.vendor;
}
