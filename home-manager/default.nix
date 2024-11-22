{
  username,
  host,
  ...
}:
{
  imports =
    if (host == "desktop") then [ ../modules/home/default.desktop.nix ] else [ ../modules/home ];

  nixpkgs = {
    config = {
      allowUnfree = true;
      allowUnfreePredicate = _: true;
    };
  };

  home.username = "${username}";
  home.homeDirectory = "/home/${username}";
  home.stateVersion = "24.11";
  programs.home-manager.enable = true;
}
