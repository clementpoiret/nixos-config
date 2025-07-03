{ ... }:
{
  programs.superfile = {
    enable = true;
    settings = {
      auto_check_update = false;

      default_directory = ".";
      default_sort_type = 2;
      code_previewer = "bat";
      nerdfont = true;

      theme = "catppuccin-mocha";

      border_top = "─";
      border_bottom = "─";
      border_left = "│";
      border_right = "│";
      border_top_left = "┌";
      border_top_right = "┐";
      border_bottom_left = "└";
      border_bottom_right = "┘";
      border_middle_left = "├";
      border_middle_right = "┤";
    };
  };
}
