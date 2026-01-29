{ pkgs, ... }:
{
  home.packages = with pkgs; [
    wl-kbptr
    wlrctl
  ];

  xdg.configFile."wl-kbptr/config".text = # toml
    ''
      [mode_tile]
      label_color=#cdd6f4
      label_select_color=#f38ba8
      unselectable_bg_color=#1e1e2e40
      selectable_bg_color=#1e1e2eB3
      selectable_border_color=#b4befe
      label_font_family=sans-serif
      label_symbols=abcdefghijklmnopqrstuvwxyz

      [mode_floating]
      label_color=#cdd6f4
      label_select_color=#f38ba8
      unselectable_bg_color=#1e1e2e40
      selectable_bg_color=#1e1e2eB3
      selectable_border_color=#b4befe
      label_font_family=sans-serif
      label_symbols=abcdefghijklmnopqrstuvwxyz
    '';
}
