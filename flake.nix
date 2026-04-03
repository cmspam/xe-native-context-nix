{
  description = "Intel Xe drm_native_context for NixOS VM guests";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs, ... }: {
    nixosModules.default = { config, pkgs, lib, ... }:
    let
      cfg = config.hardware.xe-virtio;

      mesaPatch = self + "/patches/mesa-01-xe-native-context-plus-iris-upload-fix.patch";
      ihdPatch = self + "/patches/intel-media-driver-xe-native-context.patch";

      patchedMesa = pkgs.mesa.overrideAttrs (old: {
        patches = old.patches ++ [ mesaPatch ];
        mesonFlags = old.mesonFlags ++ [ "-Dintel-virtio-experimental=true" ];
      });

      patchedMesa32 = pkgs.pkgsi686Linux.mesa.overrideAttrs (old: {
        patches = old.patches ++ [ mesaPatch ];
        mesonFlags = old.mesonFlags ++ [ "-Dintel-virtio-experimental=true" ];
      });

      patchedIHD = pkgs.intel-media-driver.overrideAttrs (old: {
        patches = old.patches ++ [ ihdPatch ];
      });

      patchedIHD32 = pkgs.pkgsi686Linux.intel-media-driver.overrideAttrs (old: {
        patches = old.patches ++ [ ihdPatch ];
      });
    in {
      options.hardware.xe-virtio = {
        enable = lib.mkEnableOption "Intel Xe drm_native_context for virtio-gpu guests";

        vaapi = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Enable VA-API hardware video acceleration (requires patched intel-media-driver).";
        };
      };

      config = lib.mkIf cfg.enable {
        hardware.graphics = {
          enable = true;
          enable32Bit = lib.mkDefault true;

          extraPackages = lib.optionals cfg.vaapi [
            patchedIHD
            pkgs.vpl-gpu-rt
          ];

          extraPackages32 = lib.optionals (cfg.vaapi && config.hardware.graphics.enable32Bit) [
            patchedIHD32
          ];
        };

        system.replaceDependencies.replacements = [
          { original = pkgs.mesa;     replacement = patchedMesa; }
          { original = pkgs.mesa.out; replacement = patchedMesa.out; }
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
