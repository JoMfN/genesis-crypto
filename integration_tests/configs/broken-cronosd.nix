{
  pkgs ? import ../../nix { },
}:
let
  genesisd = (pkgs.callPackage ../../. { });
in
genesisd.overrideAttrs (oldAttrs: {
  patches = oldAttrs.patches or [ ] ++ [ ./broken-genesisd.patch ];
})
