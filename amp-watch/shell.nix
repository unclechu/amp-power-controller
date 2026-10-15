{ pkgs ? import <nixpkgs> {}
}:

pkgs.mkShell {
  nativeBuildInputs = [
    pkgs.gcc
    pkgs.pkg-config
    pkgs.jack-example-tools
  ];

  buildInputs = [
    pkgs.jack2
  ];
}
