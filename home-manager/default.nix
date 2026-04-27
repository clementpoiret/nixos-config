{
  username,
  host,
  ...
}:
{
  imports =
    if (host == "desktop") then [ ../modules/home/default.desktop.nix ] else [ ../modules/home ];

  home = {
    username = "${username}";
    homeDirectory = "/home/${username}";
    stateVersion = "26.05";
  };
  programs.home-manager.enable = true;
}
