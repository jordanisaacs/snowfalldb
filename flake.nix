{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    rust-overlay.url = "github:oxalica/rust-overlay";
    neovim-flake.url = "github:jordanisaacs/neovim-flake";
    crate2nix = {
      url = "github:jordanisaacs/crate2nix/target-vendor";
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
    mustangTarget = "x86_64-mustang-linux-gnu";
    path = "nightlyRust";
    pkgsFunc = import nixpkgs;

    overlays = [
      rust-overlay.overlays.default
      (self: super: {
        ${path} = let
          r = self.rust-bin.selectLatestNightlyWith (toolchain: toolchain.default.override {extensions = ["rust-src"];});
          rustc = r;
          cargo = r;
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
      })
    ];

    pkgs = pkgsFunc {
      config = {};
      inherit localSystem overlays;
    };

    mustangLib = import ./nix {lib = pkgs.lib;};

    mustangPkgs = pkgsFunc {
      inherit localSystem overlays;
      crossSystem = {
        system = localSystem;
        rustc = mustangLib.rustcCross {inherit pkgs mustangTarget;};
      };
    };

    sysroot = mustangLib.buildSysroot path mustangPkgs;

    makeApp = {
      rootFeatures ? ["default"],
      release ? true,
    }:
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

    generatedRustBuild = makeApp {};

    snowfalldb =
      generatedRustBuild
      .rootCrate
      .build
      .override {
        runTests = true;
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

    rustEnv = {
      RUST_TARGET_PATH = mustangLib.mustangTargets pkgs;
    };

    nativeBuildInputs = with pkgs; [
      nightlyRust.rustc
      rust-bindgen
      rustPlatform.bindgenHook

      (import crate2nix {inherit pkgs;})
      # exmapModule

      cargo
      cargo-edit
      cargo-audit
      cargo-tarpaulin
      clippy

      bear

      # runQemu
      # runGdb
      gdb
    ];

    compileFlags = "-I${kernel.dev}/lib/modules/${kernel.modDirVersion}/source/include";
  in {
    packages.${localSystem} = {
      inherit snowfalldb sysroot;
      nightlyRust = pkgs.nightlyRust;
    };

    devShells.${localSystem}.default = pkgs.mkShell ({
        # NIX_CFLAGS_COMPILE = compileFlags;
        # KERNEL = kernel.dev;
        # KERNEL_VERSION = kernel.modDirVersion;
        nativeBuildInputs =
          nativeBuildInputs
          ++ [neovim];
      }
      // rustEnv);
  };
}
