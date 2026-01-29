{ pkgs, ... }:
{
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

      debug = false;
      ignore_missing_fields = false;

      code_previewer = "bat";
      nerdfont = true;
      transparent_background = true;

      zoxide_support = true;

      cd_on_quit = false;
      default_open_file_preview = true;
      show_image_preview = true;
      show_panel_footer_info = true;
      file_size_use_si = false;
      shell_close_on_success = false;
      file_preview_width = 0;
      sidebar_width = 20;

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
