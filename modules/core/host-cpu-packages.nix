{
  host,
  lib,
  ...
}:

let
  cpuTargets = {
    desktop = "znver5";
    laptop = "znver4";
  };
  cpuTarget =
    cpuTargets.${host} or (throw "host-cpu-packages: no CPU target configured for host ${host}");

  appendFlag =
    old: flag:
    if old == null then
      flag
    else if builtins.isList old then
      old ++ [ flag ]
    else
      "${old} ${flag}";

  rustFor =
    pkg:
    pkg.overrideAttrs (
      old:
      if builtins.isAttrs (old.env or null) then
        {
          # Generic builders may not support the host CPU instructions emitted
          # for test binaries. Keep the optimized build without executing it.
          doCheck = false;
          doInstallCheck = false;
          env = old.env // {
            RUSTFLAGS = appendFlag (old.env.RUSTFLAGS or null) "-C target-cpu=${cpuTarget}";
          };
        }
      else
        {
          doCheck = false;
          doInstallCheck = false;
          RUSTFLAGS = appendFlag (old.RUSTFLAGS or null) "-C target-cpu=${cpuTarget}";
        }
    );

  replaceGhosttyCpu =
    flags:
    if builtins.any (lib.hasInfix "-Dcpu=baseline") flags then
      map (flag: lib.replaceStrings [ "-Dcpu=baseline" ] [ "-Dcpu=${cpuTarget}" ] flag) flags
    else if builtins.any (lib.hasInfix "-Dcpu=${cpuTarget}") flags then
      flags
    else
      throw "host-cpu-packages: Ghostty no longer exposes -Dcpu=baseline";
in
{
  nixpkgs.overlays = lib.mkAfter [
    (
      _final: prev:
      let
        quickshellHost = prev.quickshell.overrideAttrs (old: {
          NIX_CFLAGS_COMPILE = appendFlag (old.NIX_CFLAGS_COMPILE or null) "-march=${cpuTarget}";
        });
        niriHost = rustFor prev.niri-unstable;
        ghosttyHost = prev.ghostty.overrideAttrs (old: {
          zigBuildFlags = replaceGhosttyCpu old.zigBuildFlags;
          zigCheckFlags = replaceGhosttyCpu old.zigCheckFlags;
        });
      in
      {
        quickshell-host = quickshellHost;
        quickshell = quickshellHost;

        niri-host = niriHost;
        niri = niriHost;
        niri-unstable = niriHost;

        ghostty-host = ghosttyHost;
        ghostty = ghosttyHost;
      }
    )
  ];
}
