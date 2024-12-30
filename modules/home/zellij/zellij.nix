{ config, ... }:
{
  programs.zellij.enable = true;
  home.file = {
    ".config/zellij/themes/catppuccin.yaml".source = ./themes/catppuccin.yaml;
    ".config/zellij/config.kdl".text =
      builtins.replaceStrings
        [ "$ZELLIJ_THEMES" ]
        [ "${config.home.homeDirectory}/.config/zellij/themes/" ]
        (builtins.readFile ./config.kdl);

    # Current version: 0.2.2rc1
    ".config/zellij/plugins/zellij-autolock.wasm".source = ./plugins/zellij-autolock.wasm;
  };
}
