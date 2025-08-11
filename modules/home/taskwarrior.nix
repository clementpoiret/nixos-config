{ pkgs, ... }:
{
  programs.taskwarrior = {
    enable = true;
    package = pkgs.taskwarrior3;
    dataLocation = "~/Sync/Notes/task";
  };

  # WARN: syncall is currently broken. Use uvx
  # home.packages = with pkgs; [ syncall ];
  programs.nushell.shellAliases = {
    "tw" = "task";

    "twl" = "task list";

    "twa" = "task add +shared";

    "twapl" = "task add +shared priority:L";
    "twapm" = "task add +shared priority:M";
    "twaph" = "task add +shared priority:H";

    "twad" = "task add +shared due:today";
    "twaw" = "task add +shared due:eow";
    "twam" = "task add +shared due:eom";

    "twsr" = "task start";
    "twsp" = "task stop";
    "twd" = "task done";

    # currently, remember that syncall is broken on nixpkgs,
    # it needs to be installed via uvx (uvx install syncall[...])
    "twsync" = "tw_gtasks_sync -t shared -l Shared";
  };
}
