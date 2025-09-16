{ ... }:
{
  programs.hyprlock = {
    enable = true;

    settings = {
      disable_loading_bar = true;
      hide_cursor = true;

      label = [
        {
          monitor = "";
          text = "cmd[update:30000] echo \"<b><big> $(date +\"%R\") </big></b>\"";
          font_size = 110;
          shadow_passes = 3;
          shadow_size = 3;
          position = "0, -100";
          halign = "center";
          valign = "top";
        }
        {
          monitor = "";
          text = "cmd[update:43200000] echo \"$(date +\"%A, %d %B %Y\")\"";
          font_size = 18;
          position = "0, -300";
          halign = "center";
          valign = "top";
        }
      ];
    };
  };
}
