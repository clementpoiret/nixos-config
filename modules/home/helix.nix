{ ... }:
{
  programs.helix = {
    enable = true;

    languages = {
      language-server = {
        basedpyright.config = {
          basedpyright.analysis.typeCheckingMode = "basic";
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
          name = "python";
          language-servers = [
            "ruff"
            "basedpyright"
          ];
        }
      ];
    };

    settings = {
      theme = "catppuccin_mocha";

      editor = {
        cursorline = true;
        line-number = "relative";
        rulers = [ 120 ];
        true-color = true;

        auto-format = true;

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

          "C-x".g = ":sh zellij run -ci -- lazygit";

          "=" = ":format";

          # "{" = [
          #   "goto_prev_paragraph"
          #   "collapse_selection"
          # ];
          # "}" = [
          #   "goto_next_paragraph"
          #   "collapse_selection"
          # ];
          # "0" = "goto_line_start";
          # "$" = "goto_line_end";
          # "^" = "goto_first_nonwhitespace";
          # G = "goto_file_end";
          # "%" = "match_brackets";
          # V = [
          #   "select_mode"
          #   "extend_to_line_bounds"
          # ];
          # D = [
          #   "extend_to_line_end"
          #   "yank_main_selection_to_clipboard"
          #   "delete_selection"
          # ];

          # x = "delete_selection";
          # p = [
          #   "paste_clipboard_after"
          #   "collapse_selection"
          # ];
          # P = [
          #   "paste_clipboard_before"
          #   "collapse_selection"
          # ];
          # Y = [
          #   "extend_to_line_end"
          #   "yank_main_selection_to_clipboard"
          #   "collapse_selection"
          # ];

          esc = [
            "collapse_selection"
            "keep_primary_selection"
          ];

          # d = {
          #   d = [
          #     "extend_to_line_bounds"
          #     "yank_main_selection_to_clipboard"
          #     "delete_selection"
          #   ];
          #   t = [ "extend_till_char" ];
          #   s = [ "surround_delete" ];
          #   i = [ "select_textobject_inner" ];
          #   a = [ "select_textobject_around" ];
          #   j = [
          #     "select_mode"
          #     "extend_to_line_bounds"
          #     "extend_line_below"
          #     "yank_main_selection_to_clipboard"
          #     "delete_selection"
          #     "normal_mode"
          #   ];
          #   down = [
          #     "select_mode"
          #     "extend_to_line_bounds"
          #     "extend_line_below"
          #     "yank_main_selection_to_clipboard"
          #     "delete_selection"
          #     "normal_mode"
          #   ];
          #   k = [
          #     "select_mode"
          #     "extend_to_line_bounds"
          #     "extend_line_above"
          #     "yank_main_selection_to_clipboard"
          #     "delete_selection"
          #     "normal_mode"
          #   ];
          #   up = [
          #     "select_mode"
          #     "extend_to_line_bounds"
          #     "extend_line_above"
          #     "yank_main_selection_to_clipboard"
          #     "delete_selection"
          #     "normal_mode"
          #   ];
          #   G = [
          #     "select_mode"
          #     "extend_to_line_bounds"
          #     "goto_last_line"
          #     "extend_to_line_bounds"
          #     "yank_main_selection_to_clipboard"
          #     "delete_selection"
          #     "normal_mode"
          #   ];
          #   w = [
          #     "move_next_word_start"
          #     "yank_main_selection_to_clipboard"
          #     "delete_selection"
          #   ];
          #   W = [
          #     "move_next_long_word_start"
          #     "yank_main_selection_to_clipboard"
          #     "delete_selection"
          #   ];
          #   g = {
          #     g = [
          #       "select_mode"
          #       "extend_to_line_bounds"
          #       "goto_file_start"
          #       "extend_to_line_bounds"
          #       "yank_main_selection_to_clipboard"
          #       "delete_selection"
          #       "normal_mode"
          #     ];
          #   };
          # };

          # y = {
          #   y = [
          #     "extend_to_line_bounds"
          #     "yank_main_selection_to_clipboard"
          #     "normal_mode"
          #     "collapse_selection"
          #   ];
          #   j = [
          #     "select_mode"
          #     "extend_to_line_bounds"
          #     "extend_line_below"
          #     "yank_main_selection_to_clipboard"
          #     "collapse_selection"
          #     "normal_mode"
          #   ];
          #   down = [
          #     "select_mode"
          #     "extend_to_line_bounds"
          #     "extend_line_below"
          #     "yank_main_selection_to_clipboard"
          #     "collapse_selection"
          #     "normal_mode"
          #   ];
          #   k = [
          #     "select_mode"
          #     "extend_to_line_bounds"
          #     "extend_line_above"
          #     "yank_main_selection_to_clipboard"
          #     "collapse_selection"
          #     "normal_mode"
          #   ];
          #   up = [
          #     "select_mode"
          #     "extend_to_line_bounds"
          #     "extend_line_above"
          #     "yank_main_selection_to_clipboard"
          #     "collapse_selection"
          #     "normal_mode"
          #   ];
          #   G = [
          #     "select_mode"
          #     "extend_to_line_bounds"
          #     "goto_last_line"
          #     "extend_to_line_bounds"
          #     "yank_main_selection_to_clipboard"
          #     "collapse_selection"
          #     "normal_mode"
          #   ];
          #   w = [
          #     "move_next_word_start"
          #     "yank_main_selection_to_clipboard"
          #     "collapse_selection"
          #     "normal_mode"
          #   ];
          #   W = [
          #     "move_next_long_word_start"
          #     "yank_main_selection_to_clipboard"
          #     "collapse_selection"
          #     "normal_mode"
          #   ];
          #   g = {
          #     g = [
          #       "select_mode"
          #       "extend_to_line_bounds"
          #       "goto_file_start"
          #       "extend_to_line_bounds"
          #       "yank_main_selection_to_clipboard"
          #       "collapse_selection"
          #       "normal_mode"
          #     ];
          #   };
          # };

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
          "C-a" = {
            "C-a" = ":sh zellij ac toggle-floating-panes";
            "z" = ":sh zellij ac toggle-fullscreen";
            "n" = ":sh zellij ac new-pane";
            "v" = ":sh zellij ac new-pane -d right";
            "h" = ":sh zellij ac new-pane -d down";
          };

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
            "collapse_selection"
            "move_visual_line_down"
            "goto_first_nonwhitespace"
            "normal_mode"
          ];
        };

        insert = {
          esc = [
            "collapse_selection"
            "normal_mode"
          ];
        };

        select = {
          # "{" = [
          #   "extend_to_line_bounds"
          #   "goto_prev_paragraph"
          # ];
          # "}" = [
          #   "extend_to_line_bounds"
          #   "goto_next_paragraph"
          # ];
          # "0" = "goto_line_start";
          # "$" = "goto_line_end";
          # "^" = "goto_first_nonwhitespace";
          # G = "goto_file_end";
          # D = [
          #   "extend_to_line_bounds"
          #   "delete_selection"
          #   "normal_mode"
          # ];
          # "%" = "match_brackets";
          # u = [
          #   "switch_to_lowercase"
          #   "collapse_selection"
          #   "normal_mode"
          # ];
          # U = [
          #   "switch_to_uppercase"
          #   "collapse_selection"
          #   "normal_mode"
          # ];

          # i = "select_textobject_inner";
          # a = "select_textobject_around";

          # "C-i" = [
          #   "insert_mode"
          #   "collapse_selection"
          # ];
          # "C-a" = [
          #   "append_mode"
          #   "collapse_selection"
          # ];

          # k = [
          #   "extend_line_up"
          #   "extend_to_line_bounds"
          # ];
          # j = [
          #   "extend_line_down"
          #   "extend_to_line_bounds"
          # ];

          # d = [
          #   "yank_main_selection_to_clipboard"
          #   "delete_selection"
          # ];
          # x = [
          #   "yank_main_selection_to_clipboard"
          #   "delete_selection"
          # ];
          # y = [
          #   "yank_main_selection_to_clipboard"
          #   "normal_mode"
          #   "flip_selections"
          #   "collapse_selection"
          # ];
          # Y = [
          #   "extend_to_line_bounds"
          #   "yank_main_selection_to_clipboard"
          #   "goto_line_start"
          #   "collapse_selection"
          #   "normal_mode"
          # ];
          # p = "replace_selections_with_clipboard";
          # P = "paste_clipboard_before";

          esc = [
            "collapse_selection"
            "keep_primary_selection"
            "normal_mode"
          ];

          # REPL
          "C-space" = [
            ":sh zellij ac move-focus-or-tab right"
            ":pipe-to sh -c 'zellij ac write-chars \"$(cat)\n\"'"
            ":sh zellij ac move-focus-or-tab left"
            "collapse_selection"
            "move_visual_line_down"
            "goto_first_nonwhitespace"
            "normal_mode"
          ];
        };
      };
    };
  };
}
