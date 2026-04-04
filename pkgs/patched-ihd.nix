{ patchSrc, ihdPkg }:

ihdPkg.overrideAttrs (old: {
  patches = (old.patches or [ ]) ++ [
    "${patchSrc}/intel-media-driver-xe-native-context.patch"
  ];
})
