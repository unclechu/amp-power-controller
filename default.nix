{ pkgs ? import <nixpkgs> {}
, callPackage ? pkgs.callPackage

, amp-watch ? callPackage ./amp-watch {}

, inNixShell ? false
}:

let
  pico-sdk = pkgs.pico-sdk.override {
    withSubmodules = true; # Enable USB serial module for TTY interface
  };

  shell = pkgs.mkShell {
    packages = [
      pkgs.cmake
      pkgs.python3 # cmake needs it
      pkgs.ninja
      pkgs.gcc-arm-embedded
      pkgs.picotool
      pico-sdk
    ];

    shellHook = ''
      export PICO_SDK_PATH="${pico-sdk}/lib/pico-sdk"
    '';
  };
in

(if inNixShell then shell else {}) // {
  inherit shell pico-sdk;
  inherit (amp-watch) amp-power-controller-jack-watch;
}
