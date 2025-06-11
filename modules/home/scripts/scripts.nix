{ pkgs, ... }:
let
  wall-change = pkgs.writeShellScriptBin "wall-change" (builtins.readFile ./scripts/wall-change.sh);
  wallpaper-picker = pkgs.writeShellScriptBin "wallpaper-picker" (
    builtins.readFile ./scripts/wallpaper-picker.sh
  );

  runbg = pkgs.writeShellScriptBin "runbg" (builtins.readFile ./scripts/runbg.sh);
  music = pkgs.writeShellScriptBin "music" (builtins.readFile ./scripts/music.sh);
  lofi = pkgs.writeScriptBin "lofi" (builtins.readFile ./scripts/lofi.sh);

  toggle_blur = pkgs.writeScriptBin "toggle_blur" (builtins.readFile ./scripts/toggle_blur.sh);
  toggle_oppacity = pkgs.writeScriptBin "toggle_oppacity" (
    builtins.readFile ./scripts/toggle_oppacity.sh
  );
  toggle_waybar = pkgs.writeScriptBin "toggle_waybar" (builtins.readFile ./scripts/toggle_waybar.sh);
  toggle_float = pkgs.writeScriptBin "toggle_float" (builtins.readFile ./scripts/toggle_float.sh);
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

  show-keybinds = pkgs.writeScriptBin "show-keybinds" (builtins.readFile ./scripts/keybinds.sh);

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
    wall-change
    wallpaper-picker

    runbg
    music
    lofi

    toggle_blur
    toggle_oppacity
    toggle_waybar
    toggle_float
    toggle_suspend
    suspend_state

    maxfetch

    compress
    extract

    select-sink

    shutdown-script

    show-keybinds

    ascii

    record

    run_nvim

    cycle-fan-strategy

    manage-dns
  ];
}
