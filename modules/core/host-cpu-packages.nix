{
  hostFacts,
  lib,
  ...
}:

let
  cpuTarget = hostFacts.hardware.cpuTarget;

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

  replaceNiriCompletionGenerator =
    baseline: postInstall:
    let
      optimizedCommand = "$out/bin/niri completions";
    in
    if lib.hasInfix optimizedCommand postInstall then
      lib.replaceStrings [ optimizedCommand ] [ "${baseline}/bin/niri completions" ] postInstall
    else
      throw "host-cpu-packages: Niri no longer generates completions with its installed binary";

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
        herdrHost = rustFor prev.flake.herdr;
        niriBaseline = prev.flake.niri-unstable;
        niriHost = (rustFor niriBaseline).overrideAttrs (old: {
          # GitHub's generic builders cannot execute host-optimized binaries.
          # Use the baseline package only to generate architecture-independent completions.
          postInstall = replaceNiriCompletionGenerator niriBaseline (old.postInstall or "");
        });
        ghosttyHost = prev.ghostty.overrideAttrs (old: {
          # The version check executes the installed binary, which generic
          # GitHub runners may not support after host CPU optimization.
          doInstallCheck = false;
          zigBuildFlags = replaceGhosttyCpu old.zigBuildFlags;
          zigCheckFlags = replaceGhosttyCpu old.zigCheckFlags;
        });
      in
      {
        flake = prev.flake // {
          herdr = herdrHost;
        };

        quickshell-host = quickshellHost;
        quickshell = quickshellHost;

        niri-host = niriHost;
        niri-baseline = niriBaseline;
        niri = niriHost;
        niri-unstable = niriHost;

        ghostty-host = ghosttyHost;
        ghostty = ghosttyHost;
      }
    )
  ];
}
