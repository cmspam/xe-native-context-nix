{
  description = "Intel Xe drm_native_context for NixOS VM guests";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    mesa-src = {
      url = "gitlab:mesa/mesa/main?host=gitlab.freedesktop.org";
      flake = false;
    };
  };

  outputs = { nixpkgs, mesa-src, ... }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      lib = pkgs.lib;

      # Important:
      # Do NOT reference `self + "/patches/..."` here.
      # We deliberately isolate only the patch files so unrelated
      # edits in the repo do not perturb the package derivations.
      patchSrc = builtins.path {
        path = ./patches;
        name = "xe-virtio-patches";
        filter = path: type:
          let
            base = builtins.baseNameOf path;
          in
            type == "directory"
            || base == "mesa-01-xe-native-context-plus-iris-upload-fix.patch"
            || base == "intel-media-driver-xe-native-context.patch";
      };

      patchedMesa = import ./pkgs/patched-mesa.nix {
        inherit pkgs mesa-src patchSrc;
        mesaPkg = pkgs.mesa;
      };

      patchedMesa32 = import ./pkgs/patched-mesa.nix {
        inherit pkgs mesa-src patchSrc;
        mesaPkg = pkgs.pkgsi686Linux.mesa;
      };

      patchedIHD = import ./pkgs/patched-ihd.nix {
        inherit patchSrc;
        ihdPkg = pkgs.intel-media-driver;
      };

      patchedIHD32 = import ./pkgs/patched-ihd.nix {
        inherit patchSrc;
        ihdPkg = pkgs.pkgsi686Linux.intel-media-driver;
      };

      xeVirtioModule = import ./modules/xe-virtio.nix {
        inherit lib patchedMesa patchedMesa32 patchedIHD patchedIHD32;
      };
    in {
      packages.${system} = {
        mesa = patchedMesa;
        mesa32 = patchedMesa32;
        ihd = patchedIHD;
        ihd32 = patchedIHD32;
      };

      nixosModules.default = xeVirtioModule;
    };
}
