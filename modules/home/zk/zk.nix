{ config, host, lib, pkgs, ... }:
let
  dir = if (host == "desktop") then "/mnt/hdd/Sync/Notes/zk/" else "/home/clementpoiret/Sync/Notes/zk/";
in 
{
  home.packages = [ pkgs.zk ];
  #home.file.".config/zk/config.toml" = { source = ./config.toml; };
  # TODO: Wait for PR in zk to be merged to fix symlinks.
  # then, I'll be able to remove this if to use
  # "${config.home.homeDirectory}Sync/Notes/zk/";
  home.sessionVariables = {
    ZK_NOTEBOOK_DIR = dir; 
  };
}
