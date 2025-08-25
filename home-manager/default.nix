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
    stateVersion = "25.05";
  };
  programs.home-manager.enable = true;
}
