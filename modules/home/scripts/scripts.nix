{ pkgs, ... }:
let
  runbg = pkgs.writeShellScriptBin "runbg" (builtins.readFile ./scripts/runbg.sh);
  scripts = map (name: pkgs.writeScriptBin name (builtins.readFile (./scripts + "/${name}.sh"))) [
    "lofi"
    "toggle_suspend"
    "suspend_state"
    "maxfetch"
    "compress"
    "extract"
    "select-sink"
    "shutdown-script"
    "ascii"
    "record"
    "run_nvim"
    "cycle-fan-strategy"
    "manage-dns"
  ];
  nixos-config-agent = pkgs.writeShellApplication {
    name = "nixos-config-agent";
    runtimeInputs = [
      pkgs.delta
      pkgs.git
      pkgs.gnupg
      pkgs.jujutsu
      pkgs.openssh
      pkgs.python3
    ];
    text = ''
      exec python3 ${./nixos_config_agent.py} "$@"
    '';
  };
in
{
  home.packages = [ runbg ] ++ scripts ++ [ nixos-config-agent ];
}
