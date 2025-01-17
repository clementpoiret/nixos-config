{ pkgs, ... }:
{
  home.packages = with pkgs; [ aichat ];

  xdg.configFile."aichat/config.yaml".text = # yaml
    ''
      # llm
      model: claude
      clients:
        - type: claude

      # behavior
      keybindings: vi
      editor: hx
    '';
}
