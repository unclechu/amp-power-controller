{ pkgs ? import <nixpkgs> {}
, lib ? pkgs.lib
, stdenv ? pkgs.stdenv

, inNixShell ? false
}:

let
  shell = pkgs.mkShell {
    nativeBuildInputs = [
      pkgs.gcc
      pkgs.pkg-config
      pkgs.jack-example-tools
    ];

    buildInputs = [
      pkgs.jack2
    ];
  };

  amp-power-controller-jack-watch = stdenv.mkDerivation (lib.fix (self: {
    pname = "amp-power-controller-jack-watch";
    version = "0.0.1";

    src = ./main.c;

    dontUnpack = true;
    dontConfigure = true;

    nativeBuildInputs = [
      pkgs.pkg-config
    ];

    buildInputs = [
      pkgs.jack2
    ];

    buildPhase = ''
      runHook preBuild

      CFLAGS=$(pkg-config --cflags jack)
      LIBS=$(pkg-config --libs jack)

      COMPILE_CMD=(
        $CC -std=c11 -O2 -Wall -Wextra -Wpedantic
        $CFLAGS
        "$src" -o ${lib.escapeShellArg self.pname}
        $LIBS -pthread
      )

      "''${COMPILE_CMD[@]}"

      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall

      install -Dm755 \
        ${lib.escapeShellArg self.pname} \
        "$out/bin/"${lib.escapeShellArg self.pname}

      runHook postInstall
    '';

    doCheck = true;

    checkPhase = ''
      runHook preCheck

      >check-atomic.c printf %s ${lib.escapeShellArg ''
        #include <stdatomic.h>
        #include <stdint.h>
        #include <stdio.h>

        static atomic_uint_fast64_t atomic_test_var = ATOMIC_VAR_INIT(0);

        int main(void) {
          if (!atomic_is_lock_free(&atomic_test_var)) {
            fprintf(stderr, "A 64-bit atomic is not lock-free on this CPU.\n");
            return 1;
          }
          return 0;
        }
      ''}

      $CC -std=c11 -O2 check-atomic.c -o check-atomic
      ./check-atomic

      runHook postCheck
    '';
  }));
in

(if inNixShell then shell else {}) // {
  inherit shell amp-power-controller-jack-watch;
}
