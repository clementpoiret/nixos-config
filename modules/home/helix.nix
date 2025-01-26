{ ... }:
{
  programs.helix = {
    enable = true;
    defaultEditor = true;

    # TODO: Ltex-ls-plus
    # TODO: simple-completion-language-server
    languages = {
      language-server = {
        basedpyright.config = {
          basedpyright.analysis.typeCheckingMode = "basic";
        };

        bibli-ls = {
          command = "bibli_ls";
          required-root-patterns = [
            ".bibli.toml"
          ];
        };
        zk = {
          command = "zk";
          args = [ "lsp" ];
          required-root-patterns = [
            ".zk"
          ];
        };
      };
      ruff = {
        config.settings = {
          lineLength = 120;
          indent-width = 4;
          lint = {
            select = [ "ALL" ];
            ignore = [ ];
          };
        };
      };

      language = [
        {
          name = "nix";
          auto-format = true;
        }
        {
          name = "lua";
          auto-format = true;
        }
        {
          name = "rust";
          auto-format = true;
        }
        {
          name = "zig";
          auto-format = true;
        }
        {
          name = "python";
          auto-format = true;
          language-servers = [
            "ruff"
            "basedpyright"
          ];
        }
        {
          name = "markdown";
          auto-format = true;
          roots = [
            ".marksman.toml"
            ".zk"
            ".bibli.toml"
          ];
          language-servers = [
            "bibli-ls"
            "ltex-ls-plus"
            "marksman"
            "zk"
          ];
          formatter = {
            # TODO: use mdformat.withPlugins once fixed
            command = "uvx";
            args = [
              "--with"
              "mdformat-gfm"
              "--with"
              "mdformat-frontmatter"
              "--with"
              "mdformat-footnote"
              "--from"
              "mdformat"
              "mdformat"
              "-"
            ];
          };
        }
      ];
    };

    settings = {
      theme = "catppuccin_mocha_mod";

      editor = {
        cursorline = true;
        line-number = "relative";
        rulers = [ 120 ];
        color-modes = true;
        true-color = true;
        mouse = false;

        auto-format = true;

        file-picker.hidden = false;

        statusline = {
          left = [
            "mode"
            "version-control"
            "file-name"
            "read-only-indicator"
            "file-modification-indicator"
          ];

          center = [
            "position"
            "position-percentage"
          ];

          right = [
            "spinner"
            "diagnostics"
          ];
        };

        cursor-shape = {
          normal = "block";
          insert = "bar";
          select = "underline";
        };

        indent-guides = {
          character = "╎";
          render = true;
        };

        lsp = {
          display-messages = true;
          # display-inlay-hints = true;
        };

        end-of-line-diagnostics = "hint";

        inline-diagnostics = {
          cursor-line = "error";
          other-lines = "disable";
        };

      };

      keys = {
        normal = {
          space.space = "file_picker";

          "=" = ":format";

          j = [
            "move_visual_line_down"
            "align_view_center"
          ];
          k = [
            "move_visual_line_up"
            "align_view_center"
          ];
          n = [
            "search_next"
            "align_view_center"
          ];
          N = [
            "search_prev"
            "align_view_center"
          ];
          "+" = [
            "move_line_down"
            "align_view_center"
          ];
          "-" = [
            "move_line_up"
            "align_view_center"
          ];

          esc = [
            "collapse_selection"
            "keep_primary_selection"
          ];
          ret = [
            # "move_line_down"
            # "goto_first_nonwhitespace"
            "goto_word"
          ];
          "0" = "goto_line_start";
          "*" = [
            "move_char_right"
            "move_prev_word_start"
            "move_next_word_end"
            "search_selection"
            "make_search_word_bounded"
            "search_next"
          ];
          "#" = [
            "move_char_right"
            "move_prev_word_start"
            "move_next_word_end"
            "search_selection"
            "make_search_word_bounded"
            "search_prev"
          ];

          # Zellij stuff
          space.ret = ":sh zellij run -ci -- lazygit";
          "C-a" = {
            "C-a" = ":sh zellij ac toggle-floating-panes";
            "z" = ":sh zellij ac toggle-fullscreen";
            "n" = ":sh zellij ac new-pane";
            "v" = ":sh zellij ac new-pane -d right";
            "h" = ":sh zellij ac new-pane -d down";
            "r" = [
              ":sh zellij ac new-pane -d right -- devenv shell repl"
              ":sh zellij ac move-focus left"
            ];
          };
          "C-t".n = ":sh zellij ac new-tab";

          "C-h" = ":sh zellij ac move-focus-or-tab left";
          "C-j" = ":sh zellij ac move-focus-or-tab down";
          "C-k" = ":sh zellij ac move-focus-or-tab up";
          "C-l" = ":sh zellij ac move-focus-or-tab right";

          # REPL
          "C-space" = [
            "select_mode"
            "extend_to_line_bounds"
            ":sh zellij ac move-focus-or-tab right"
            ":pipe-to sh -c 'zellij ac write-chars \"$(cat)\n\"'"
            ":sh zellij ac move-focus-or-tab left"
            "move_visual_line_down"
            "goto_first_nonwhitespace"
            "collapse_selection"
            "normal_mode"
          ];
          "C-esc" = [
            "goto_first_nonwhitespace"
            "select_mode"
            "extend_to_line_end"
            ":sh zellij ac move-focus-or-tab right"
            ":pipe-to sh -c 'zellij ac write-chars \"$(cat)\n\"'"
            ":sh zellij ac move-focus-or-tab left"
            "move_visual_line_down"
            "goto_first_nonwhitespace"
            "collapse_selection"
            "normal_mode"
          ];
        };

        insert = {
          esc = [
            "collapse_selection"
            "normal_mode"
          ];

          # REPL
          "C-space" = [
            "select_mode"
            "extend_to_line_bounds"
            ":sh zellij ac move-focus-or-tab right"
            ":pipe-to sh -c 'zellij ac write-chars \"$(cat)\n\"'"
            ":sh zellij ac move-focus-or-tab left"
            "collapse_selection"
            "insert_mode"
          ];
          "C-esc" = [
            "goto_first_nonwhitespace"
            "select_mode"
            "extend_to_line_end"
            ":sh zellij ac move-focus-or-tab right"
            ":pipe-to sh -c 'zellij ac write-chars \"$(cat)\n\"'"
            ":sh zellij ac move-focus-or-tab left"
            "collapse_selection"
            "insert_mode"
          ];
        };

        select = {
          "+" = [
            "extend_line_down"
            "align_view_center"
          ];
          "-" = [
            "extend_line_up"
            "align_view_center"
          ];

          esc = [
            "collapse_selection"
            "keep_primary_selection"
            "normal_mode"
          ];
          "0" = "goto_line_start";
          ret = [
            # "move_line_down"
            # "goto_first_nonwhitespace"
            "extend_to_word"
          ];

          # REPL
          "C-space" = [
            ":sh zellij ac move-focus-or-tab right"
            ":pipe-to sh -c 'rg -v \"^[[:space:]]*$\" | zellij ac write-chars \"$(cat)\n\"'"
            ":sh zellij ac move-focus-or-tab left"
            "collapse_selection"
            "move_visual_line_down"
            "goto_first_nonwhitespace"
            "collapse_selection"
            "normal_mode"
          ];
        };
      };
    };

    themes.catppuccin_mocha_mod = {
      inherits = "catppuccin_mocha";
      "ui.virtual.jump-label" = {
        fg = "rosewater";
        modifiers = [ "bold" ];
        underline.style = "line";
      };
    };
  };
}
