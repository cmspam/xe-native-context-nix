{ lib, patchedMesa, patchedMesa32, patchedIHD, patchedIHD32 }:

{ config, pkgs, ... }:
let
  cfg = config.hardware.xe-virtio;
in {
  options.hardware.xe-virtio = {
    enable = lib.mkEnableOption "Intel Xe drm_native_context for virtio-gpu guests";

    vaapi = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable VA-API userspace bits for the patched stack.";
    };
  };

  config = lib.mkIf cfg.enable {
    hardware.graphics = {
      enable = true;
      enable32Bit = lib.mkDefault true;
      package = patchedMesa;
      extraPackages = lib.optionals cfg.vaapi [ patchedIHD pkgs.vpl-gpu-rt ];
      extraPackages32 =
        lib.optionals (cfg.vaapi && config.hardware.graphics.enable32Bit) [ patchedIHD32 ];
    };

    system.replaceDependencies.replacements =
      [
        { original = pkgs.mesa; replacement = patchedMesa; }
        { original = pkgs.mesa.out; replacement = patchedMesa.out; }
      ]
      ++ lib.optionals cfg.vaapi [
        { original = pkgs.intel-media-driver; replacement = patchedIHD; }
        { original = pkgs.intel-media-driver.out; replacement = patchedIHD.out; }
        { original = pkgs.intel-media-driver.dev; replacement = patchedIHD.dev; }
      ]
      ++ lib.optionals config.hardware.graphics.enable32Bit [
        { original = pkgs.pkgsi686Linux.mesa; replacement = patchedMesa32; }
        { original = pkgs.pkgsi686Linux.mesa.out; replacement = patchedMesa32.out; }
      ]
      ++ lib.optionals (cfg.vaapi && config.hardware.graphics.enable32Bit) [
        { original = pkgs.pkgsi686Linux.intel-media-driver; replacement = patchedIHD32; }
        { original = pkgs.pkgsi686Linux.intel-media-driver.out; replacement = patchedIHD32.out; }
        { original = pkgs.pkgsi686Linux.intel-media-driver.dev; replacement = patchedIHD32.dev; }
      ];

    environment.sessionVariables =
      {
        VK_ICD_FILENAMES =
          "/run/opengl-driver/share/vulkan/icd.d/intel_icd.x86_64.json"
          + lib.optionalString config.hardware.graphics.enable32Bit
            ":/run/opengl-driver-32/share/vulkan/icd.d/intel_icd.i686.json";
      }
      // lib.optionalAttrs cfg.vaapi {
        LIBVA_DRIVER_NAME = "iHD";
      };
  };
}
