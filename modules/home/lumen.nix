{ pkgs, ... }:
{
  home.packages = [ pkgs.flake.lumen ];

  xdg.configFile."lumen/lumen.config.json".text = builtins.toJSON {
    theme = "catppuccin-mocha";
    wrap = false;
  };
}
