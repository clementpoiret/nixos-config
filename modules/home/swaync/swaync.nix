{ pkgs, ... }: {
  home.packages = (with pkgs; [ swaynotificationcenter ]);
  xdg.configFile = {
    "swaync/style.css".source = ./style.css;
    "swaync/config.json".source = ./config.json;
    "swaync/icons" = {
      source = ./icons;
      recursive = true;
    };
    "swaync/themes" = {
      source = ./themes;
      recursive = true;
    };
  };

}
