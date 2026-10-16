{ pkgs ? import <nixpkgs> {}
, callPackage ? pkgs.callPackage

, jack-watch ? callPackage ./jack-watch {}
, pico-firmware ? callPackage ./pico-firmware {}
}:

{
  inherit (pico-firmware)
    amp-power-controller-pico-firmware
    amp-power-switch
    ;
  inherit (jack-watch)
    amp-power-controller-jack-watch
    ;
}
