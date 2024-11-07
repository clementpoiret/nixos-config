{ pkgs, ... }: 
{
  programs.kitty = {
    enable = true;

    themeFile = "Catppuccin-Mocha";
    
    font = {
      name = "MonaspiceNe Nerd Font";
      size = 11;
    };

    settings = {
      adjust_line_height = 0;
      adjust_column_width = 0;

      # Cursor settings
      cursor_blink_interval = "0.5";
      cursor_stop_blinking_after = "15.0";

      # URL setting
      url_style = "double";
      url_open_modifiers = "ctrl+shift";
      copy_on_select = "yes";

      # Mouse settings
      click_interval = "0.5";
      mouse_hide_wait = 0;
      focus_follows_mouse = "no";

      # Performance Settings
      repaint_delay = 20;
      input_delay = 2;
      sync_to_monitor = "no";

      # Shell Settings
      shell = ".";
      close_on_child_death = "no";
      allow_remote_control = "no";
      term = "xterm-256color";

      # Window settings
      remember_window_size = "no";
      confirm_os_window_close = 0;
      background_opacity = "1.0";
      inactive_text_alpha = "1.0";
      window_padding_width = 0;
      window_border_width = 0;
      window_margin_width = 0;
      scrollback_lines = 10000;
      enable_audio_bell = false;
      
      ## Style
      tab_title_template = "{title}{' :{}:'.format(num_windows) if num_windows > 1 else ''}";
      tab_bar_min_tabs = 1;
      tab_bar_edge = "bottom";
      active_tab_font_style = "normal";
      inactive_tab_font_style = "normal";
      tab_bar_style = "powerline";
      tab_powerline_style = "slanted";
      active_tab_foreground = "#1e1e2e";
      active_tab_background = "#cba6f7";
      inactive_tab_foreground = "#bac2de";
      inactive_tab_background = "#313244";
      wayland_titlebar_color = "system";

      # Mouse bindings
      mouse_map = "right press ungrabbed paste_from_selection";
    };

    keybindings = {
      ## Tabs
      "alt+1" = "goto_tab 1";
      "alt+2" = "goto_tab 2";
      "alt+3" = "goto_tab 3";
      "alt+4" = "goto_tab 4";

      ## Copy Paste
      "alt+shift+v" = "paste_from_clipboard";
      "alt+shift+s" = "paste_from_selection";
      "alt+shift+c" = "copy_to_clipboard";
      "shift+insert" = "paste_from_selection";

      ## Scroll
      "alt+shift+up" = "scroll_line_up";
      "alt+shift+down" = "scroll_line_down";
      "alt+shift+k" = "scroll_line_up";
      "alt+shift+j" = "scroll_line_down";
      "alt+shift+page_up" = "scroll_page_up";
      "alt+shift+page_down" = "scroll_page_down";
      "alt+shift+home" = "scroll_home";
      "alt+shift+end" = "scroll_end";
      "alt+shift+h" = "show_scrollback";

      ## Window
      "alt+shift+enter" = "new_window";
      "alt+shift+n" = "new_os_window";
      "alt+shift+w" = "close_window";
      "alt+shift+]" = "next_window";
      "alt+shift+[" = "previous_window";
      "alt+shift+f" = "move_window_forward";
      "alt+shift+b" = "move_window_backward";
      "alt+shift+`" = "move_window_to_top";
      "alt+shift+1" = "first_window";
      "alt+shift+2" = "second_window";
      "alt+shift+3" = "third_window";
      "alt+shift+4" = "fourth_window";
      "alt+shift+5" = "fifth_window";
      "alt+shift+6" = "sixth_window";
      "alt+shift+7" = "seventh_window";
      "alt+shift+8" = "eighth_window";
      "alt+shift+9" = "ninth_window";
      "alt+shift+0" = "tenth_window";

      ## Tabs
      "alt+shift+right" = "next_tab";
      "alt+shift+left" = "previous_tab";
      "alt+shift+t" = "new_tab";
      "alt+shift+q" = "close_tab";
      "alt+shift+l" = "next_layout";
      "alt+shift+." = "move_tab_forward";
      "alt+shift+," = "move_tab_backward";

      ## Zoom
      "alt+shift+equal" = "increase_font_size";
      "alt+shift+minus" = "decrease_font_size";
      "alt+shift+backspace" = "restore_font_size";
      "alt+shift+f11" = "set_font_size 11.0";
      "alt+shift+f6" = "set_font_size 16.0";

      ## Unbind
      "ctrl+shift+left" = "no_op";
      "ctrl+shift+right" = "no_op";
    };
  };
}
