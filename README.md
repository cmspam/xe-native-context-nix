# xe-native-context-nix

NixOS flake module for Intel Xe GPU acceleration in QEMU/KVM virtual machines via `drm_native_context`.

This patches Mesa and intel-media-driver for the **guest VM** to enable OpenGL, Vulkan, and VA-API over virtio-gpu native context with Intel Xe GPUs.

For background on what these patches do and how the architecture works, see [xe-native-context-enablement](https://github.com/cmspam/xe-native-context-enablement).

## Quick Start

Add this flake to your NixOS VM guest configuration:

```nix
# flake.nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    xe-native-context.url = "github:cmspam/xe-native-context-nix";
  };

  outputs = { nixpkgs, xe-native-context, ... }: {
    nixosConfigurations.my-vm = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        xe-native-context.nixosModules.default
        {
          hardware.xe-virtio.enable = true;
        }
        # ... your other VM configuration
      ];
    };
  };
}
```

That's it. Rebuild and you have hardware-accelerated OpenGL, Vulkan, and VA-API in your guest.

## What It Does

When `hardware.xe-virtio.enable = true`, the module:

- Patches Mesa with Xe virtio ccmd support and replaces the system Mesa via `system.replaceDependencies`. This rewrites store-path references in the final system closure so all packages use the patched Mesa **without being rebuilt from source** -- only Mesa itself is compiled.
- Patches intel-media-driver with a vdrm shim for VA-API, replaced the same way.
- Sets `LIBVA_DRIVER_NAME=iHD` for VA-API.
- Enables 32-bit graphics support by default (both Mesa and intel-media-driver are replaced for 32-bit as well).

## Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `hardware.xe-virtio.enable` | bool | `false` | Enable Xe native context support |
| `hardware.xe-virtio.vaapi` | bool | `true` | Enable VA-API (set to `false` if you don't need hardware video) |

## Host Requirements

The host must be running:
- A recent QEMU build from git with virtio-gpu native context support
- Patched virglrenderer with the Xe renderer backend (see [xe-native-context-enablement](https://github.com/cmspam/xe-native-context-enablement))

QEMU flags for the VM:

```
-accel kvm,honor-guest-pat=on
-device virtio-vga-gl,blob=on,hostmem=4G,drm_native_context=on
```

## Tested Hardware

- Intel Arc B390 (iGPU on Core X7 358H / Lunar Lake)

Reports from other Xe-based GPUs welcome -- please open an issue.

## License

The modified files in these patches are MIT/X11 licensed (see SPDX headers in each patched file).
