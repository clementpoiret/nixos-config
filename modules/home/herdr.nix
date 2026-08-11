{ pkgs, ... }:
{
  home.packages = [ pkgs.flake.herdr ];

  xdg.configFile."herdr/config.toml".text = # toml
    ''
      [theme]
      name = "rose-pine"

      [keys]
      # Use Ctrl-Space as Herdr's prefix.
      prefix = "ctrl+space"

      # Normal pane focus:
      # - retain Herdr/Helix's semantic h/j/k/l bindings;
      # - add the arrows produced by the ZMK NAV layer.
      focus_pane_left  = ["prefix+h", "prefix+left"]
      focus_pane_down  = ["prefix+j", "prefix+down"]
      focus_pane_up    = ["prefix+k", "prefix+up"]
      focus_pane_right = ["prefix+l", "prefix+right"]

      # Navigator pane focus:
      # The same four physical right-home-row keys produce:
      #
      #   Base Ergo-L:  r  t  i  u
      #   ZMK NAV:      ←  ↓  ↑  →
      #
      # Retain h/j/k/l as semantic fallbacks.
      navigate_pane_left  = ["h", "r"]
      navigate_pane_down  = ["j", "t"]
      navigate_pane_up    = ["k", "i"]
      navigate_pane_right = ["l", "u"]

      # `[` requires AltGr on Ergo-L. Retain the default and add a
      # Helix-style `y` mnemonic for entering copy/yank mode.
      copy_mode = ["prefix+[", "prefix+y"]
    '';
}
