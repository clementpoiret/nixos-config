{ pkgs }:

pkgs.python3.withPackages (p: with p; [
  requests # HTTP library
])
