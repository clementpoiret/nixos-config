{ pkgs, ... }:
{
  programs.btop = {
    enable = true;

    settings = {
      update_ms = 500;
    };
  };

  home.packages = (with pkgs; [ nvtopPackages.intel ]);
}
