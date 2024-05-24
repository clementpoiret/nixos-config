{ pkgs, ... }: 
{
  programs.git = {
    enable = true;
    
    userName = "clementpoiret";
    userEmail = "poiret.clement@outlook.fr";
    
    extraConfig = { 
      init.defaultBranch = "main";
      credential.helper = "store";
      commit.gpgsign = true;
      gpg.format = "ssh";
      gpg.ssh.allowedSignersFile = "~/.ssh/allowed_signers";
      user.signingkey = "~/.ssh/id_ed25519_sk_blue.pub";
      user.identityFile = "~/.ssh/id_ed25519_sk_blue";
    };
  };

  # home.packages = [ pkgs.gh pkgs.git-lfs ];
}
