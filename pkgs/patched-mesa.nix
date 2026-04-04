{ pkgs, mesa-src, patchSrc, mesaPkg }:

mesaPkg.overrideAttrs (old: {
  pname = "mesa-xe-virtio";
  version = "26.1.0-git";
  src = mesa-src;

  patches = (old.patches or [ ]) ++ [
    "${patchSrc}/mesa-01-xe-native-context-plus-iris-upload-fix.patch"
  ];

  mesonFlags = (old.mesonFlags or [ ]) ++ [
    "-Dintel-virtio-experimental=true"
  ];

  nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [
    pkgs.python3Packages.mako
    pkgs.python3Packages.pyyaml
  ];
})
