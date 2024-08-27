{ pkgs, ... }: {
  programs.git = {
    enable = true;

    userName = "clementpoiret";
    userEmail = "poiret.clement@outlook.fr";

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
      core.sshCommand = "ssh -i /home/clementpoiret/.ssh/id_ed25519_sk_main";
      commit.gpgsign = true;
      gpg.format = "ssh";
      gpg.ssh.allowedSignersFile = "~/.ssh/allowed_signers";
      # status.showUntrackedFiles = "no";
      user.signingkey = "~/.ssh/id_ed25519_sk_main.pub";
      merge.conflictstyle = "diff3";
      diff.colorMoved = "default";
    };
  };

  # home.packages = [ pkgs.gh pkgs.git-lfs ];
}
