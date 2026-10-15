{ pkgs ? import <nixpkgs> {}
}:

let
  pico-sdk = pkgs.pico-sdk.override {
    withSubmodules = true; # Enable USB serial module for TTY interface
  };
in

pkgs.mkShell {
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
}
