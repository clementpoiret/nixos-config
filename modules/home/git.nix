{ pkgs, ... }: 
{
  programs.git = {
    enable = true;
    
    userName = "clementpoiret";
    userEmail = "poiret.clement@outlook.fr";
    
    extraConfig = { 
      init.defaultBranch = "main";
      credential.helper = "store";
    };
  };

  # home.packages = [ pkgs.gh pkgs.git-lfs ];
}
