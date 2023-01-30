{
  inputs = {
    nixpkgs.url = "nixpkgs/nixpkgs-unstable";
    rust-overlay.url = "github:oxalica/rust-overlay";
    neovim-flake.url = "github:jordanisaacs/neovim-flake";
    crate2nix = {
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
    system = "x86_64-linux";
    # target = "x86_64-mustang-linux-gnu";
    overlays = [
      rust-overlay.overlays.default
      (self: super: let
        rust = super.rust-bin.selectLatestNightlyWith (toolchain: toolchain.default.override {extensions = ["rust-src" "miri"];});
      in {
        rustc = rust;
        cargo = rust;
      })
    ];

    pkgs = import nixpkgs {
      inherit system overlays;
      # crossSystem = {
      #   inherit system;
      #   rustc = {
      #     config = target;
      #     platform = builtins.fromJSON "${mustangTargets}/${target}.json";
      #   };
      # };
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
          defaultCrateOverrides =
            pkgs.defaultCrateOverrides
            // {
              exmap = attrs: {
                NIX_CFLAGS_COMPILE = compileFlags;
                buildInputs = [pkgs.rustPlatform.bindgenHook exmapModule.dev];
              };
            };
        };
    in
      pkgs.callPackage ./Cargo.nix {
        inherit buildRustCrateForPkgs;
      };

    snowfalldb =
      generatedRustBuild
      .rootCrate
      .build;

    nativeBuildInputs = with pkgs; [
      rustc
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
    ];

    compileFlags = "-I${kernel.dev}/lib/modules/${kernel.modDirVersion}/source/include";
  in
    with pkgs; {
      packages.${system} = {
        # inherit snowfalldb;
      };

      devShells.${system}.default = mkShell ({
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
