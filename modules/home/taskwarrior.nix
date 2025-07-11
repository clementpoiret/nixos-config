{ pkgs, ... }:
{
  programs.taskwarrior = {
    enable = true;
    package = pkgs.taskwarrior3;
    dataLocation = "~/Sync/Notes/task";
  };
}
