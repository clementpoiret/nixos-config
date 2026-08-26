{ config, pkgs, ... }:
let
  jjMergeConfig = "${config.xdg.configHome}/helix/jj-merge.toml";
in
{
  home.file.lesskey.text = "Q toggle-option -!^Predraw-on-quit\nq";

  xdg.configFile."helix/jj-merge.toml".text = # toml
    ''
      [editor]
      bufferline = "always"
      cursorline = true
      auto-format = false
      auto-completion = false

      [editor.lsp]
      enable = false

      [editor.statusline]
      left = [
        "mode",
        "file-name",
        "file-modification-indicator",
      ]
      right = [
        "position",
        "file-type",
      ]
    '';

  programs.jujutsu = {
    enable = true;
    settings = {
      user = {
        name = "Clément POIRET";
        email = "clement@linux.com";
      };
      signing = {
        behavior = "own";
        backend = "gpg";
        key = "71F084CEA427B23537934233CC6B0EED323A6C13";
      };
      git.sign-on-push = true;
      ui = {
        default-command = "log";
        merge-editor = "hx";

        show-cryptographic-signatures = true;

        pager = [
          "delta"
          "--diff-so-fancy"
          "--side-by-side"
        ];
        diff-formatter = ":git";
      };
      merge-tools.hx = {
        program = "hx";
        merge-args = [
          "--config"
          jjMergeConfig
          "$output"
          "$left"
          "$base"
          "$right"
        ];
        merge-tool-edits-conflict-markers = true;
        conflict-marker-style = "snapshot";
      };
    };
  };

  home.packages = with pkgs; [ jjui ];
}
