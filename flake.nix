{
  description = "Intel Xe drm_native_context for NixOS VM guests";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    mesa-src = {
      url = "gitlab:mesa/mesa/main?host=gitlab.freedesktop.org";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, mesa-src, ... }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      lib = pkgs.lib;

      # Patched Mesa Logic
      makePatchedMesa = mesaPkg: mesaPkg.overrideAttrs (old: {
        pname = "mesa-xe-virtio";
        version = "26.1.0-git";
        src = mesa-src;
        patches = (old.patches or [ ]) ++ [
          (self + "/patches/mesa-01-xe-native-context-plus-iris-upload-fix.patch")
        ];
        mesonFlags = (old.mesonFlags or [ ]) ++ [
          "-Dintel-virtio-experimental=true"
        ];
        nativeBuildInputs = (old.nativeBuildInputs or []) ++ [ 
          pkgs.python3Packages.mako 
          pkgs.python3Packages.pyyaml 
        ];
      });

      # Patched IHD Logic
      makePatchedIHD = ihdPkg: ihdPkg.overrideAttrs (old: {
        patches = (old.patches or [ ]) ++ [
          (self + "/patches/intel-media-driver-xe-native-context.patch")
        ];
      });

      patchedMesa = makePatchedMesa pkgs.mesa;
      patchedMesa32 = makePatchedMesa pkgs.pkgsi686Linux.mesa;
      patchedIHD = makePatchedIHD pkgs.intel-media-driver;
      patchedIHD32 = makePatchedIHD pkgs.pkgsi686Linux.intel-media-driver;

    in {
      packages.${system} = {
        mesa = patchedMesa;
        ihd = patchedIHD;
      };

      nixosModules.default = { config, pkgs, ... }:
        let cfg = config.hardware.xe-virtio;
        in {
          options.hardware.xe-virtio = {
            enable = lib.mkEnableOption "Intel Xe drm_native_context for virtio-gpu guests";
            vaapi = lib.mkOption {
              type = lib.types.bool;
              default = true;
            };
          };

          config = lib.mkIf cfg.enable {
            hardware.graphics = {
              enable = true;
              enable32Bit = lib.mkDefault true;
              package = patchedMesa;
              extraPackages = lib.optionals cfg.vaapi [ patchedIHD pkgs.vpl-gpu-rt ];
              extraPackages32 = lib.optionals (cfg.vaapi && config.hardware.graphics.enable32Bit) [ patchedIHD32 ];
            };

            # YOUR EXPLICIT REPLACEMENT LIST
            system.replaceDependencies.replacements = [
              { original = pkgs.mesa;           replacement = patchedMesa; }
              { original = pkgs.mesa.out;       replacement = patchedMesa.out; }
            ] ++ lib.optionals cfg.vaapi [
              { original = pkgs.intel-media-driver;     replacement = patchedIHD; }
              { original = pkgs.intel-media-driver.out; replacement = patchedIHD.out; }
              { original = pkgs.intel-media-driver.dev; replacement = patchedIHD.dev; }
            ] ++ lib.optionals config.hardware.graphics.enable32Bit [
              { original = pkgs.pkgsi686Linux.mesa;     replacement = patchedMesa32; }
              { original = pkgs.pkgsi686Linux.mesa.out; replacement = patchedMesa32.out; }
            ] ++ lib.optionals (cfg.vaapi && config.hardware.graphics.enable32Bit) [
              { original = pkgs.pkgsi686Linux.intel-media-driver;     replacement = patchedIHD32; }
              { original = pkgs.pkgsi686Linux.intel-media-driver.out; replacement = patchedIHD32.out; }
              { original = pkgs.pkgsi686Linux.intel-media-driver.dev; replacement = patchedIHD32.dev; }
            ];

            environment.sessionVariables = lib.mkIf cfg.vaapi {
              LIBVA_DRIVER_NAME = "iHD";
            };
          };
        };
    };
}
