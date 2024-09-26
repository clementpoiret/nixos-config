{ pkgs, ... }: {
  programs.git = {
    enable = true;

    userName = "clementpoiret";
    userEmail = "poiret.clement@outlook.fr";
    signing.key = "71F084CEA427B23537934233CC6B0EED323A6C13";
    #signing.key = "~/.ssh/id_ed25519_sk_main.pub";

    delta = {
      enable = true;
      options = {
        line-numbers = true;
        side-by-side = true;
        navigate = true;
      };
    };

    extraConfig = {
      init.defaultBranch = "main";
      credential.helper = "cache";
      #core.sshCommand = "ssh -i /home/clementpoiret/.ssh/id_ed25519_pwd";
      commit.gpgsign = true;
      diff.colorMoved = "default";
      gpg.format = "openpgp";
      gpg.ssh.allowedSignersFile = "~/.ssh/allowed_signers";
      # status.showUntrackedFiles = "no";
      merge.conflictstyle = "diff3";
    };
  };

  # home.packages = [ pkgs.gh pkgs.git-lfs ];
  programs.gpg = {
    enable = true;
  };

  services.gpg-agent = {
    enable = true;
    enableSshSupport = true;
  };
}
