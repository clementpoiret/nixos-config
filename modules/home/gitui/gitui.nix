{ pkgs, ... }: {
  home.packages = [ pkgs.gitui ];
  home.file.".config/gitui/theme.ron" = { source = ./theme.ron; };
}
