{ pkgs, ... }:
{
  programs.git = {
    enable = true;

    userName = "clementpoiret";
    userEmail = "me@int8.tech";
    signing.key = "BBA69D0DB3494EDD127D7C80A0288D6D0CD0D231";

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
  };

  home.packages = [ pkgs.mergiraf ];

  home.file.".gitattributes".source = ./gitattributes;
}
