{ ... }:
{
  xdg.configFile."helix/yazi-picker.sh".text = # sh
    ''
      #!/usr/bin/env bash

      paths=$(yazi --chooser-file=/dev/stdout | while read -r; do printf "%q " "$REPLY"; done)

      if [[ -n "$paths" ]]; then
          zellij action toggle-floating-panes
          zellij action write 27 # send <Escape> key
          zellij action write-chars ":$1 $paths"
          zellij action write 13 # send <Enter> key
      else
          zellij action toggle-floating-panes
      fi
    '';

  xdg.configFile."helix/serpl-replace.sh".text = # sh
    ''
      #!/usr/bin/env bash

      serpl
      exit_code=$?

      if [[ $exit_code -eq 0 ]]; then
          zellij action toggle-floating-panes
          zellij action write-chars ":reload-all"
          zellij action write 13 # send <Enter> key
      fi
    '';

  programs.helix = {
    enable = true;
    defaultEditor = true;

    # TODO: Ltex-ls-plus
    # TODO: simple-completion-language-server
    languages = {
      language-server = {
        tinymist = {
          command = "tinymist";
          config = {
            exportPdf = "onType";
            outputPath = "$root/target/$dir/$name";
            formatterMode = "typstyle";
            formatterPrintWidth = 80;
            lint.enabled = true;
          };
        };
        basedpyright.config = {
          basedpyright.analysis.typeCheckingMode = "off";
        };
        # pylyzer = {
        #   command = "pylyzer";
        #   args = [ "--server" ];
        # };
        bibli-ls = {
          command = "bibli_ls";
          required-root-patterns = [
            ".bibli.toml"
          ];
        };
        ty = {
          command = "ty";
          args = [ "server" ];
        };
        zk = {
          command = "zk";
          args = [ "lsp" ];
          required-root-patterns = [
            ".zk"
          ];
        };
        rubocop = {
          command = "rubocop";
          args = [ "--lsp" ];
        };
        ruby-lsp = {
          command = "ruby-lsp";
          config = {
            diagnostics = true;
            formatting = true;
            config = {
              initializationOptions = {
                enabledFeatures = {
                  codeActions = true;
                  codeLens = true;
                  completion = true;
                  definition = true;
                  diagnostics = true;
                  documentHighlights = true;
                  documentLink = true;
                  documentSymbols = true;
                  foldingRanges = true;
                  formatting = true;
                  hover = true;
                  inlayHint = true;
                  onTypeFormatting = true;
                  selectionRanges = true;
                  semanticHighlighting = true;
                  signatureHelp = true;
                  typeHierarchy = true;
                  workspaceSymbol = true;
                };
                featuresConfiguration = {
                  inlayHint = {
                    implicitHashValue = true;
                    implicitRescue = true;
                  };
                };
              };
            };
          };
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
            "basedpyright"
            "ruff"
            "ty"
            # "pylyzer"
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
        {
          name = "typst";
          auto-format = true;
          language-servers = [ "tinymist" ];
        }
        {
          name = "ruby";
          language-servers = [
            "rubocop"
            "ruby-lsp"
          ];
          auto-format = true;
        }
        {
          name = "erb";
          language-servers = [
            "ruby-lsp"
          ];
          auto-format = true;
          formatter = {
            command = "erb-format";
            args = [ "--stdin" ];
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

        file-picker.hidden = true;

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
          space = {
            space = "file_picker";
            m.l = ":theme modus_operandi";
            m.d = ":theme modus_vivendi";
          };

          # Movements
          j = [
            "move_visual_line_down"
            "align_view_center"
          ];
          k = [
            "move_visual_line_up"
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
          ret = [
            "goto_word"
          ];
          "0" = "goto_line_start";

          esc = [
            "collapse_selection"
            "keep_primary_selection"
          ];

          # Search
          n = [
            "search_next"
            "align_view_center"
          ];
          N = [
            "search_prev"
            "align_view_center"
          ];
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
          # space.ret = ":sh zellij run -ci -- lazygit";
          # "C-a" = {
          #   "C-a" = ":sh zellij ac toggle-floating-panes";
          #   "z" = ":sh zellij ac toggle-fullscreen";
          #   "n" = ":sh zellij ac new-pane";
          #   "v" = ":sh zellij ac new-pane -d right";
          #   "h" = ":sh zellij ac new-pane -d down";
          #   "r" = [
          #     ":sh zellij ac new-pane -d right -- devenv shell repl"
          #     ":sh zellij ac move-focus left"
          #   ];
          #   "left" = ":sh zellij ac move-focus-or-tab left";
          #   "down" = ":sh zellij ac move-focus-or-tab down";
          #   "up" = ":sh zellij ac move-focus-or-tab up";
          #   "right" = ":sh zellij ac move-focus-or-tab right";
          # };
          # "C-t".n = ":sh zellij ac new-tab";

          # tmux stuff
          space.ret = ":sh tmux popup -d '#{pane_current_path}' -E -w 90% -h 90% lazygit";

          # REPL
          # "C-space" = [
          #   "select_mode"
          #   "extend_to_line_bounds"
          #   ":sh zellij ac move-focus-or-tab right"
          #   ":pipe-to sh -c 'zellij ac write-chars \"$(cat)\n\"'"
          #   ":sh zellij ac move-focus-or-tab left"
          #   "move_visual_line_down"
          #   "goto_first_nonwhitespace"
          #   "collapse_selection"
          #   "normal_mode"
          # ];
          # REPL: Send current line to 'REPL' pane
          "C-space" = [
            "select_mode"
            "extend_to_line_bounds"
            # Pipe selection to tmux: load to buffer, paste to 'REPL', send Enter
            ":pipe-to sh -c 'tmux load-buffer - && tmux paste-buffer -t REPL && tmux send-keys -t REPL Enter'"
            "collapse_selection"
            "move_visual_line_down"
            "goto_first_nonwhitespace"
            "normal_mode"
          ];
          # "C-esc" = [
          #   "goto_first_nonwhitespace"
          #   "select_mode"
          #   "extend_to_line_end"
          #   ":sh zellij ac move-focus-or-tab right"
          #   ":pipe-to sh -c 'zellij ac write-chars \"$(cat)\n\"'"
          #   ":sh zellij ac move-focus-or-tab left"
          #   "move_visual_line_down"
          #   "goto_first_nonwhitespace"
          #   "collapse_selection"
          #   "normal_mode"
          # ];
          # REPL: Send from start of line to end of line to 'REPL' pane
          "C-e" = [
            "goto_first_nonwhitespace"
            "select_mode"
            "extend_to_line_end"
            # Pipe selection to tmux: load to buffer, paste to 'REPL', send Enter
            ":pipe-to sh -c 'tmux load-buffer - && tmux paste-buffer -t REPL && tmux send-keys -t REPL Enter'"
            "collapse_selection"
            "move_visual_line_down"
            "goto_first_nonwhitespace"
            "normal_mode"
          ];

          # Yazi
          space.q = {
            q = ":sh zellij run -c -f -x 10% -y 10% --width 80% --height 80% -- bash ~/.config/helix/yazi-picker.sh open";
            v = ":sh zellij run -c -f -x 10% -y 10% --width 80% --height 80% -- bash ~/.config/helix/yazi-picker.sh vsplit";
            s = ":sh zellij run -c -f -x 10% -y 10% --width 80% --height 80% -- bash ~/.config/helix/yazi-picker.sh hsplit";
          };

          # Search and Replace
          # space.H = ":sh zellij run -c -f -x 10% -y 10% --width 80% --height 80% -- bash ~/.config/helix/serpl-replace.sh";
          space.H = ":sh tmux display-popup -w 80% -h 80% -E 'bash ~/.config/helix/serpl-replace.sh'";

          # Misc
          "=" = ":format";
          g = {
            v = [
              "vsplit"
              "jump_view_down"
              "goto_definition"
              "collapse_selection"
            ];
            V = [
              "hsplit"
              "jump_view_down"
              "goto_definition"
              "collapse_selection"
            ];
          };
        };

        insert = {
          esc = [
            "collapse_selection"
            "normal_mode"
          ];

          # REPL
          # "C-space" = [
          #   "select_mode"
          #   "extend_to_line_bounds"
          #   ":sh zellij ac move-focus-or-tab right"
          #   ":pipe-to sh -c 'zellij ac write-chars \"$(cat)\n\"'"
          #   ":sh zellij ac move-focus-or-tab left"
          #   "collapse_selection"
          #   "insert_mode"
          # ];
          # "C-esc" = [
          #   "goto_first_nonwhitespace"
          #   "select_mode"
          #   "extend_to_line_end"
          #   ":sh zellij ac move-focus-or-tab right"
          #   ":pipe-to sh -c 'zellij ac write-chars \"$(cat)\n\"'"
          #   ":sh zellij ac move-focus-or-tab left"
          #   "collapse_selection"
          #   "insert_mode"
          # ];

          # REPL: Send current line to 'REPL' pane, stay in insert mode
          "C-space" = [
            "select_mode"
            "extend_to_line_bounds"
            # Pipe selection to tmux: load to buffer, paste to 'REPL', send Enter
            ":pipe-to sh -c 'tmux load-buffer - && tmux paste-buffer -t REPL && tmux send-keys -t REPL Enter'"
            "collapse_selection"
            "insert_mode"
          ];

          # REPL: Send from start of line to end of line to 'REPL' pane, stay in insert mode
          "C-e" = [
            "goto_first_nonwhitespace"
            "select_mode"
            "extend_to_line_end"
            # Pipe selection to tmux: load to buffer, paste to 'REPL', send Enter
            ":pipe-to sh -c 'tmux load-buffer - && tmux paste-buffer -t REPL && tmux send-keys -t REPL Enter'"
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
            "extend_to_word"
          ];

          # REPL
          # "C-space" = [
          #   ":sh zellij ac move-focus-or-tab right"
          #   ":pipe-to sh -c 'rg -v \"^[[:space:]]*$\" | zellij ac write-chars \"$(cat)\n\"'"
          #   ":sh zellij ac move-focus-or-tab left"
          #   "collapse_selection"
          #   "move_visual_line_down"
          #   "goto_first_nonwhitespace"
          #   "collapse_selection"
          #   "normal_mode"
          # ];
          "C-space" = [
            # Pipe selection through rg (remove empty lines), then to tmux: load, paste, send Enter
            ":pipe-to sh -c 'rg -v \"^[[:space:]]*$\" | tmux load-buffer - && tmux paste-buffer -t REPL && tmux send-keys -t REPL Enter'"
            "collapse_selection"
            "move_visual_line_down"
            "goto_first_nonwhitespace"
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
