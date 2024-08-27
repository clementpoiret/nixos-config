{ pkgs, ... }: {
  programs.bat = {
    enable = true;
    config = {
      pager = "less -FR";
      theme = "Dracula";
    };
    extraPackages = with pkgs.bat-extras; [
      batman
      batpipe
      batgrep
      # batdiff is broken rn
    ];
  };
}
