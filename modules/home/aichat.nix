{ pkgs, ... }:
{
  home.packages = with pkgs; [ aichat ];

  xdg.configFile."aichat.yaml".text = # yaml
    ''
      # llm
      model: claude

      # behavior
      keybindings: vi
      editor: hx
    '';
}
