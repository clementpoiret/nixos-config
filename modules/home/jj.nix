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
        behavior = "own";
        backend = "gpg";
        key = "71F084CEA427B23537934233CC6B0EED323A6C13";
      };
      git.sign-on-push = true;
      ui = {
        default-command = "log";

        show-cryptographic-signatures = true;

        pager = [
          "delta"
          "--diff-so-fancy"
          "--side-by-side"
        ];
        diff-formatter = ":git";
      };
    };
  };

  home.packages = with pkgs; [ lazyjj ];
}
