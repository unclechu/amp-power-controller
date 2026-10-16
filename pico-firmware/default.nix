{ pkgs ? import <nixpkgs> {}
, lib ? pkgs.lib
, callPackage ? pkgs.callPackage
, stdenv ? pkgs.stdenv
, stdenvNoCC ? pkgs.stdenvNoCC

, inNixShell ? false
}:

let
  pico-sdk = pkgs.pico-sdk.override {
    withSubmodules = true; # Enable TinyUSB serial module for TTY interface
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
      export PICO_SDK_PATH=${lib.escapeShellArg "${pico-sdk}/lib/pico-sdk"}
    '';
  };

  amp-power-controller-pico-firmware = stdenv.mkDerivation {
    pname = "amp-power-controller-pico-firmware";
    version = "0.0.1";

    src = lib.fileset.toSource {
      root = ./.;
      fileset = lib.fileset.unions [
        ./CMakeLists.txt
        ./main.c
      ];
    };

    nativeBuildInputs = [
      pkgs.cmake
      pkgs.python3 # cmake needs it
      pkgs.ninja
      pkgs.gcc-arm-embedded
      pkgs.picotool
    ];

    PICO_SDK_PATH = "${pico-sdk}/lib/pico-sdk";

    dontConfigure = true;

    buildPhase = ''
      runHook preBuild

      CMAKE_CONFIGURE_CMD=(
        cmake -S . -B build -G Ninja
        -DPICO_BOARD=pico # Regular (no WiFi module) Pico board
        -Dpicotool_DIR=${lib.escapeShellArg "${pkgs.picotool}/lib/cmake/picotool"}
        # Make CMake not to download dependencies from the internet
        -DFETCHCONTENT_FULLY_DISCONNECTED=ON
      )
      "''${CMAKE_CONFIGURE_CMD[@]}"

      cmake --build build

      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall

      install -Dm644 build/amp-power-controller.uf2 "$out/firmware/amp-power-controller.uf2"
      install -Dm644 build/amp-power-controller.elf "$out/firmware/amp-power-controller.elf"

      runHook postInstall
    '';
  };

  amp-power-switch = stdenvNoCC.mkDerivation (lib.fix (self: {
    pname = "amp-power-switch";
    version = "0.0.1";

    src = ./power.sh;

    nativeBuildInputs = [
      pkgs.makeBinaryWrapper
    ];

    dontUnpack = true;
    dontBuild = true;

    installPhase = ''
      runHook preInstall

      BIN_PATH="$out/bin/"${lib.escapeShellArg self.pname}

      install -Dm755 "$src" "$BIN_PATH"
      patchShebangs "$BIN_PATH"

      wrapProgram "$BIN_PATH" \
        --prefix PATH : ${lib.escapeShellArg (lib.makeBinPath [
          pkgs.coreutils # `stty`
        ])}

      runHook postInstall
    '';
  }));
in

(if inNixShell then shell else {}) // {
  inherit
    pico-sdk
    shell
    amp-power-controller-pico-firmware
    amp-power-switch
    ;
}
