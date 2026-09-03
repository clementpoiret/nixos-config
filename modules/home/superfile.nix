{ pkgs, ... }:
let
  clipboardPath = ''
    path="$(wl-paste --no-newline)"
    if [[ -z "$path" ]]; then
      echo "Clipboard does not contain a path" >&2
      exit 1
    fi

    if ! path="$(realpath --canonicalize-existing -- "$path")"; then
      echo "Clipboard path does not exist" >&2
      exit 1
    fi
  '';

  spfDrag = pkgs.writeShellApplication {
    name = "spf-drag";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.ripdrag
      pkgs.wl-clipboard
    ];
    text = ''
      ${clipboardPath}
      ripdrag --and-exit -- "$path" </dev/null >/dev/null 2>&1 &
    '';
  };

  spfCopyFile = pkgs.writeShellApplication {
    name = "spf-copy-file";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.jq
      pkgs.wl-clipboard
    ];
    text = ''
      ${clipboardPath}
      uri="$(
        jq --null-input --raw-output --arg path "$path" \
          '$path | @uri | "file://" + gsub("%2F"; "/")'
      )"
      printf '%s\r\n' "$uri" | wl-copy --type text/uri-list
    '';
  };
in
{
  home.packages = [
    spfDrag
    spfCopyFile
  ];

  programs.superfile = {
    enable = true;
    package = pkgs.flake.superfile;

    settings = {
      theme = "rose-pine";

      editor = "hx";
      dir_editor = "nvim";

      auto_check_update = false;

      default_directory = "~";
      default_sort_type = 2;
      sort_order_reversed = false;
      case_sensitive_sort = false;
      page_scroll_size = 0;

      debug = false;
      ignore_missing_fields = false;
      file_panel_extra_columns = 0;
      file_panel_name_percent = 50;

      code_previewer = "bat";
      nerdfont = true;
      show_select_icons = true;
      transparent_background = true;

      zoxide_support = true;

      cd_on_quit = false;
      default_open_file_preview = true;
      show_image_preview = true;
      show_panel_footer_info = true;
      file_size_use_si = false;
      shell_close_on_success = false;
      file_preview_width = 0;
      enable_file_preview_border = false;
      sidebar_width = 20;
      sidebar_sections = [
        "home"
        "pinned"
        "disks"
      ];

      border_top = "─";
      border_bottom = "─";
      border_left = "│";
      border_right = "│";
      border_top_left = "╭";
      border_top_right = "╮";
      border_bottom_left = "╰";
      border_bottom_right = "╯";
      border_middle_left = "├";
      border_middle_right = "┤";

      metadata = false;
      enable_md5_checksum = false;
    };

    hotkeys =
      let
        key = primary: [
          primary
          ""
        ];
      in
      {
        confirm = [
          "enter"
          "right"
          "l"
        ];
        cd_quit = key "Q";
        quit = [
          "q"
          "esc"
        ];

        list_down = [
          "down"
          "j"
        ];
        list_up = [
          "up"
          "k"
        ];
        page_down = key "pgdown";
        page_up = key "pgup";

        close_file_panel = key "w";
        create_new_file_panel = key "n";
        next_file_panel = [
          "tab"
          "L"
        ];
        open_sort_options_menu = key "o";
        pinned_directory = key "P";
        previous_file_panel = [
          "shift+left"
          "H"
        ];
        split_file_panel = key "N";
        toggle_file_preview_panel = key "f";
        toggle_reverse_sort = key "R";

        focus_on_metadata = key "m";
        focus_on_process_bar = key "p";
        focus_on_sidebar = key "s";

        file_panel_item_create = key "ctrl+n";
        file_panel_item_rename = key "ctrl+r";

        copy_items = key "ctrl+c";
        cut_items = key "ctrl+x";
        delete_items = [
          "ctrl+d"
          "delete"
          ""
        ];
        paste_items = [
          "ctrl+v"
          "ctrl+w"
          ""
        ];
        permanently_delete_items = key "D";

        compress_file = key "ctrl+a";
        extract_file = key "ctrl+e";

        open_current_directory_with_editor = key "E";
        open_file_with_editor = key "e";

        change_panel_mode = key "v";
        # Copy the focused path, then run :spf-drag or :spf-copy-file.
        copy_path = key "ctrl+p";
        copy_present_working_directory = key "c";
        open_command_line = key ":";
        open_help_menu = key "?";
        open_spf_prompt = key ">";
        open_zoxide = key "z";
        toggle_dot_file = key ".";
        toggle_footer = key "F";

        confirm_typing = key "enter";
        cancel_typing = [
          "ctrl+c"
          "esc"
        ];

        parent_directory = [
          "h"
          "left"
          "backspace"
        ];
        search_bar = key "/";

        file_panel_select_mode_items_select_down = [
          "shift+down"
          "J"
        ];
        file_panel_select_mode_items_select_up = [
          "shift+up"
          "K"
        ];
        file_panel_select_all_items = key "A";
      };
  };

  xdg.configFile."superfile/themes/rose-pine.toml".text = # toml
    ''
      # Rosé Pine
      # Theme create by: https://github.com/pearcidar
      # Update by(sort by time):
      # 
      # Thanks for all contributor!!

      # If you want to make border display just set it same as sidebar background color

      # Code syntax highlight theme (you can go to https://github.com/alecthomas/chroma/blob/master/styles to find one you like)
      code_syntax_highlight = "rose-pine"

      # ========= Border =========
      file_panel_border = "#403d52"
      sidebar_border = "#191724"
      footer_border = "#403d52"

      # ========= Border Active =========
      file_panel_border_active = "#6e6a86"
      sidebar_border_active = "#c4a7e7"
      footer_border_active = "#f6c177"
      modal_border_active = "#908caa"

      # ========= Background (bg) =========
      full_screen_bg = "#191724"
      file_panel_bg = "#191724"
      sidebar_bg = "#191724"
      footer_bg = "#191724"
      modal_bg = "#191724"

      # ========= Foreground (fg) =========
      full_screen_fg = "#e0def4"
      file_panel_fg = "#e0def4"
      sidebar_fg = "#e0def4"
      footer_fg = "#e0def4"
      modal_fg = "#e0def4"

      # ========= Special Color =========
      cursor = "#9ccfd8"
      correct = "#31748f"
      error = "#eb6f92"
      hint = "#31748f"
      cancel = "#6e6a86"
      # Gradient color can only have two color!
      gradient_color = ["#31748f", "#eb6f92"]

      # ========= File Panel Special Items =========
      file_panel_top_directory_icon = "#9ccfd8"
      file_panel_top_path = "#ebbcba"
      file_panel_item_selected_fg = "#c4a7e7"
      file_panel_item_selected_bg = "#191724"

      # ========= Sidebar Special Items =========
      sidebar_title = "#6e6a86"
      sidebar_item_selected_fg = "#f6c177"
      sidebar_item_selected_bg = "#191724"
      sidebar_divider = "#908caa"

      # ========= Modal Special Items =========
      modal_cancel_fg = "#e0def4"
      modal_cancel_bg = "#524f67"

      modal_confirm_fg = "#e0def4"
      modal_confirm_bg = "#eb6f92"

      # ========= Help Menu =========
      help_menu_hotkey = "#f6c177"
      help_menu_title = "#9ccfd8"
    '';
}
