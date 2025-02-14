{ pkgs, ... }:
{
  home.file.lesskey.text = "Q toggle-option -!^Predraw-on-quit\nq";

  programs.jujutsu = {
    enable = true;
    settings = {
      user = {
        name = "Clément POIRET";
        email = "poiret.clement@outlook.fr";
      };
      signing = {
        sign-all = true;
        backend = "gpg";
        key = "71F084CEA427B23537934233CC6B0EED323A6C13";
      };
      git.sign-on-push = true;
      ui = {
        show-cryptographic-signatures = true;

        pager = "delta";
        diff.format = "git";
      };
    };
  };

  home.packages = with pkgs; [ stable.lazyjj ];
}
