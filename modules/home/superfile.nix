{ ... }:
{
  programs.superfile = {
    enable = true;
    settings = {
      theme = "catppuccin-mocha";

      editor = "hx";
      dir_editor = "nvim";

      auto_check_update = false;

      default_directory = ".";
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
}
