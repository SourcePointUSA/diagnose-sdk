{ 
  pkgs ? import <nixpkgs> {},
}:

pkgs.mkShell {
  buildInputs = [
    pkgs.gradle
    pkgs.kotlin
  ];
}
