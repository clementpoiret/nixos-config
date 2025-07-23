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

    "twsync" = "uvx --from syncall[google,tw] tw_gtasks_sync -t shared -l Shared; task list";
  };
}
