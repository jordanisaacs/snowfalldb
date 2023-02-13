{
  inputs = {
    nixpkgs.url = "nixpkgs/nixpkgs-unstable";
    rust-overlay.url = "github:oxalica/rust-overlay";
    neovim-flake.url = "github:jordanisaacs/neovim-flake";
    crate2nix = {
      inputs.nixpkgs.follows = "nixpkgs";
      url = "github:kolloch/crate2nix";
      flake = false;
    };
    kernelFlake = {
      url = "github:jordanisaacs/kernel-module-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    exmap.url = "github:jordanisaacs/exmap-module";
  };

  outputs = {
    self,
    nixpkgs,
    rust-overlay,
    neovim-flake,
    crate2nix,
    kernelFlake,
    exmap,
    ...
  }: let
    localSystem = "x86_64-linux";
    target = "x86_64-mustang-linux-gnu";
    pkgsFunc = import nixpkgs;

    overlays = [
      rust-overlay.overlays.default
      (self: super: let
        nightlyRust = let
          r = self.rust-bin.selectLatestNightlyWith (toolchain: toolchain.default);
          rustc = r;
          cargo = r;
          # Need the rust library source
          # the workspace crates do not put their lib.rs in a source directory.
          # Therefore, buildRustCrate won't build anything because it checks for [src/lib.rs](https://github.com/NixOS/nixpkgs/blob/583e2bc9615cdb03daafb6b49017c0609cb97ede/pkgs/build-support/rust/build-rust-crate/build-crate.nix#L65)
          # BASE=$out/rustc-std-workspace
          # for BASE_PATH in $BASE-core $BASE-alloc $BASE-std
          # do
          #   chmod +w $BASE_PATH
          #   mkdir -p $BASE_PATH/src
          #   mv $BASE_PATH/lib.rs $BASE_PATH/src
          #   chmod -w $BASE_PATH
          # done
          rustLibSrc = self.runCommand "rust-lib-src" {} ''
            mkdir $out
            cp -r ${self.rust-bin.nightly.latest.rust-src}/lib/rustlib/src/rust/library/* $out
          '';

          sysrootCargo = import ./nix/sysroot/cargo-sysroot.nix {
            pkgs = self;
            rustLibSrc = rustLibSrc;
          };
        in {
          inherit rustc cargo rustLibSrc sysrootCargo;
        };
      in {
        inherit nightlyRust;
      })
    ];

    pkgs = pkgsFunc {
      config = {};
      inherit localSystem overlays;
    };

    mustangPkgs = pkgsFunc {
      inherit localSystem overlays;
      crossSystem = {
        system = localSystem;
        rustc = {
          config = target;
          platform = builtins.fromJSON (builtins.readFile "${mustangTargets}/${target}.json");
        };
      };
    };

    mustangNix = import ./nix {
      inherit pkgs mustangPkgs;
      inherit (pkgs.nightlyRust) rustc cargo rustLibSrc;
    };

    enableGdb = true;

    linuxConfigs = pkgs.callPackage ./configs/kernel.nix {};
    inherit (linuxConfigs) kernelArgs kernelConfig;

    kernelLib = kernelFlake.lib.builders {inherit pkgs;};

    configfile = kernelLib.buildKernelConfig {
      inherit
        (kernelConfig)
        generateConfigFlags
        structuredExtraConfig
        ;
      inherit kernel nixpkgs;
    };

    kernelDrv = kernelLib.buildKernel {
      inherit
        (kernelArgs)
        src
        modDirVersion
        version
        ;

      inherit configfile nixpkgs enableGdb;
    };

    linuxDev = pkgs.linuxPackagesFor kernelDrv;
    kernel = linuxDev.kernel;
    exmapModule = exmap.lib.buildExmap kernel;

    modules = [exmapModule];
    initramfs = kernelLib.buildInitramfs {
      inherit kernel modules;
      extraBin = {};
      # extraBin = {
      #   snowfalldb = "${exmapExample}/bin/snowfalldb";
      # };
      extraInit = ''
        insmod modules/exmap.ko
        mknod -m 666 /dev/exmap c 254 0
      '';
    };

    runQemu = kernelLib.buildQemuCmd {inherit kernel initramfs enableGdb;};
    runGdb = kernelLib.buildGdbCmd {inherit kernel modules;};

    neovim = neovim-flake.lib.neovimConfiguration {
      inherit pkgs;
      modules = [./configs/editor.nix];
    };

    mustangTargets = pkgs.stdenv.mkDerivation {
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

    rustEnv = {
      RUST_TARGET_PATH = mustangTargets;
    };

    generatedRustBuild = let
      buildRustCrateForPkgs = pkgs:
        pkgs.buildRustCrate.override {
          inherit (pkgs.buildPackages.buildPackages) rust rustc cargo;
        };
      # // {
      #   exmap = attrs: {
      #     NIX_CFLAGS_COMPILE = compileFlags;
      #     buildInputs = [pkgs.rustPlatform.bindgenHook exmapModule.dev];
      #   };
      # };
    in
      mustangPkgs.callPackage ./Cargo.nix {
        inherit buildRustCrateForPkgs;
      };

    snowfalldb =
      generatedRustBuild
      .rootCrate
      .build;

    nativeBuildInputs = with pkgs; [
      nightlyRust.rustc
      rust-bindgen
      rustPlatform.bindgenHook

      pkgs.crate2nix
      exmapModule

      cargo
      cargo-edit
      cargo-audit
      cargo-tarpaulin
      clippy

      bear

      runQemu
      runGdb
      gdb
    ];

    compileFlags = "-I${kernel.dev}/lib/modules/${kernel.modDirVersion}/source/include";
  in {
    packages.${localSystem} = {
      inherit snowfalldb mustangNix;
      nightlyRust = pkgs.nightlyRust;
    };

    devShells.${localSystem}.default = pkgs.mkShell ({
        NIX_CFLAGS_COMPILE = compileFlags;
        KERNEL = kernel.dev;
        KERNEL_VERSION = kernel.modDirVersion;
        nativeBuildInputs =
          nativeBuildInputs
          ++ [neovim.neovim];
      }
      // rustEnv);
  };
}
