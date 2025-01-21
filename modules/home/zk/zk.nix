{
  config,
  host,
  pkgs,
  ...
}:
let
  dir =
    if (host == "desktop") then
      "/mnt/hdd/Sync/Notes/zk/"
    else
      "${config.home.homeDirectory}/Sync/Notes/zk/";
in
{
  home.packages = with pkgs; [
    flake.bibli-ls
    zk
  ];

  home.file."Sync/Notes/zk/permanent/.bibli.toml".text = ''
    [backends]
    [backends.library]
    backend_type = "bibfile"
    bibfiles = ["${config.home.homeDirectory}/Sync/Bibliography/library.bib"]
  '';
  home.file.".config/zk/config.toml".source = ./config.toml;

  # TODO: Wait for PR in zk to be merged to fix symlinks.
  # then, I'll be able to remove this if to use
  # "${config.home.homeDirectory}Sync/Notes/zk/";
  home.sessionVariables = {
    ZK_NOTEBOOK_DIR = dir;
  };
}
