{ pkgs, ... }:
{
  programs.jujutsu = {
    enable = true;
    settings = {
      user = {
        name = "Clément POIRET";
        email = "poiret.clement@outlook.fr";
      };
    };
  };

  home.packages = with pkgs; [ stable.lazyjj ];
}
