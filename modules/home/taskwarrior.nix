{ pkgs, ... }:
{
  programs.taskwarrior = {
    enable = true;
    package = pkgs.taskwarrior3;
    dataLocation = "~/Sync/Notes/task";
  };

  # WARN: syncall is currently broken. Use uvx
  # home.packages = with pkgs; [ syncall ];
}
