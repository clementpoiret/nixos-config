{
  hostFacts,
  inputs,
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
    buildTools: postInstall:
    let
      optimizedCommand = "$out/bin/niri completions";
    in
    if lib.hasInfix optimizedCommand postInstall then
      lib.replaceStrings [ optimizedCommand ] [ "${buildTools}/bin/niri completions" ] postInstall
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
        niriBuildTools = inputs.niri.packages.${prev.stdenv.buildPlatform.system}.niri-unstable;
        # Build the pinned source with the host libraries: Mesa is loaded from
        # /run/opengl-driver and can require a newer glibc than flake packages use.
        niriHost = (rustFor prev.niri-unstable).overrideAttrs (old: {
          # GitHub's generic builders cannot execute host-optimized binaries.
          # Upstream's cached generic build generates architecture-independent completions.
          postInstall = replaceNiriCompletionGenerator niriBuildTools (old.postInstall or "");
        });
        ghosttyHost = prev.flake.ghostty.overrideAttrs (old: {
          zigBuildFlags = replaceGhosttyCpu old.zigBuildFlags;
        });
      in
      {
        flake = prev.flake // {
          ghostty = ghosttyHost;
          herdr = herdrHost;
        };

        quickshell-host = quickshellHost;
        quickshell = quickshellHost;

        niri-host = niriHost;
        niri-build-tools = niriBuildTools;
        niri = niriHost;
        niri-unstable = niriHost;

        ghostty-host = ghosttyHost;
        ghostty = ghosttyHost;
      }
    )
  ];
}
