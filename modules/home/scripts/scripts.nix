{ pkgs, ... }:
let
  dunst-dnd = pkgs.writers.writeNuBin "dunst-dnd" (builtins.readFile ./scripts/dunst-dnd.nu);

  runbg = pkgs.writeShellScriptBin "runbg" (builtins.readFile ./scripts/runbg.sh);
  music = pkgs.writeShellScriptBin "music" (builtins.readFile ./scripts/music.sh);
  lofi = pkgs.writeScriptBin "lofi" (builtins.readFile ./scripts/lofi.sh);

  toggle_suspend = pkgs.writeScriptBin "toggle_suspend" (
    builtins.readFile ./scripts/toggle_suspend.sh
  );
  suspend_state = pkgs.writeScriptBin "suspend_state" (builtins.readFile ./scripts/suspend_state.sh);

  maxfetch = pkgs.writeScriptBin "maxfetch" (builtins.readFile ./scripts/maxfetch.sh);

  compress = pkgs.writeScriptBin "compress" (builtins.readFile ./scripts/compress.sh);
  extract = pkgs.writeScriptBin "extract" (builtins.readFile ./scripts/extract.sh);

  select-sink = pkgs.writeScriptBin "select-sink" (builtins.readFile ./scripts/select-sink.sh);

  shutdown-script = pkgs.writeScriptBin "shutdown-script" (
    builtins.readFile ./scripts/shutdown-script.sh
  );

  ascii = pkgs.writeScriptBin "ascii" (builtins.readFile ./scripts/ascii.sh);

  record = pkgs.writeScriptBin "record" (builtins.readFile ./scripts/record.sh);

  run_nvim = pkgs.writeScriptBin "run_nvim" (builtins.readFile ./scripts/run_nvim.sh);

  cycle-fan-strategy = pkgs.writeScriptBin "cycle-fan-strategy" (
    builtins.readFile ./scripts/cycle-fan-strategy.sh
  );

  manage-dns = pkgs.writeScriptBin "manage-dns" (builtins.readFile ./scripts/manage-dns.sh);
in
{
  home.packages = [
    dunst-dnd

    runbg
    music
    lofi

    toggle_suspend
    suspend_state

    maxfetch

    compress
    extract

    select-sink

    shutdown-script

    ascii

    record

    run_nvim

    cycle-fan-strategy

    manage-dns
  ];
}
