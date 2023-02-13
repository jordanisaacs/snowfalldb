{
  lib,
  stdenv,
  buildPackages,
  rustLibSrc,
  no_std ? true,
}:
stdenv.mkDerivation {
  name = "sysroot-cargo";
  preferLocalBuild = true;

  unpackPhase = "true";
  dontConfigure = true;
  dontBuild = true;

  installPhase = let
    buildLib =
      if no_std
      then ''
        echo "#![no_std] > $out/src/lib.rs"
      ''
      else ''
        touch $out/src/lib.rs
      '';
  in ''
    export RUSTC_SRC=${rustLibSrc}
    ${buildPackages.python3.withPackages (ps: with ps; [toml])}/bin/python3 ${./cargo.py}
    mkdir -p $out/src
    ${buildLib}
    cp Cargo.toml $out/Cargo.toml
    cp ${./Cargo.lock} $out/Cargo.lock
  '';
}
