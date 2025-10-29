{ pkgs, ... }:
{
  programs.git = {
    enable = true;

    settings = {
      user = {
        name = "clementpoiret";
        email = "clement@linux.com";
      };

      init.defaultBranch = "main";
      credential.helper = "cache";
      core.attributesfile = "~/.gitattributes";
      commit.gpgsign = true;
      diff.colorMoved = "default";

      gpg.format = "openpgp";
      gpg.ssh.allowedSignersFile = "~/.ssh/allowed_signers";

      merge.conflictstyle = "diff3";
      "merge \"mergiraf\"" = {
        name = "mergiraf";
        driver = "mergiraf merge --git %O %A %B -s %S -x %X -y %Y -p %P";
      };
    };

    signing.key = "BBA69D0DB3494EDD127D7C80A0288D6D0CD0D231";
  };

  programs.delta = {
    enable = true;
    enableGitIntegration = true;
    options = {
      line-numbers = true;
      side-by-side = true;
      navigate = true;
    };
  };

  home.packages = [ pkgs.mergiraf ];

  home.file.".gitattributes".source = ./gitattributes;
}
