{
  config,
  lib,
  pkgs,
  ...
}:
let
  profileDirectory = config.home.profileDirectory;
in
{
  programs.nushell = {
    enable = true;
    package = pkgs.nushell;

    configFile.source = ./config.nu;
    envFile.source = ./env.nu;

    extraConfig = ''
      # Program aliases
      use ($nu.default-config-dir | path join 'aliases/bat.nu') *
      use ($nu.default-config-dir | path join 'aliases/git.nu') *
      use ($nu.default-config-dir | path join 'aliases/k8s.nu') *
    '';

    extraEnv = ''
      # To source env variables
      # from https://github.com/tesujimath/bash-env-nushell/blob/main/bash-env.nu
      use parse-env.nu [parseenv]

      # Source /etc/set-environment to get environment variables
      parseenv /etc/set-environment | load-env

      # Same thing but for session variables set using home-manager
      parseenv ${profileDirectory}/etc/profile.d/hm-session-vars.sh | load-env

      # Fixes Micromamba and Aider
      $env.GIT_PYTHON_GIT_EXECUTABLE = "${profileDirectory}/bin/git"
    '';

    shellAliases = {
      # Because of muscle memory
      ":q" = "exit";
      ":wq" = "exit";

      # Utils
      c = "clear";
      cd = "z";
      tt = "gtrash put";
      cat = "bat";
      py = "python";
      icat = "kitten icat";
      findw = "grep -rl";
      pdf = "tdf";

      ll = "ls -l";
      la = "ls -a";
      ldu = "ls -d";

      # Nixos
      cdnix = "cd ~/nixos-config";
      ns = "nom-shell --run bash";
      nix-shell = "nix-shell --run bash";
      nix-switch = "nh os switch";
      nix-update = "nh os switch --update";
      nix-clean = "nh clean all --keep 5";
      nix-search = "nh search";
      nix-test = "nh os test";
      nix-flake-update = "sudo nix flake update ~/nixos-config#";

      # custom tools
      emacs = "emacsclient -c -a 'emacs'";
    };
  };

  home = {
    packages = with pkgs; [
      flake.bash-env-json
      jq
      nufmt
      nushellPlugins.query
      nushellPlugins.polars
    ];

    activation =
      let
        nu-plugin =
          path:
          lib.hm.dag.entryAfter [ "writeBoundary" ] ''
            run ${pkgs.nushell}/bin/nu --no-config-file --no-history --no-std-lib -c 'plugin add --plugin-config ~/.config/nushell/plugin.msgpackz ${path}'
          '';
      in
      {
        nu-plugin-query = nu-plugin "${pkgs.nushellPlugins.query}/bin/nu_plugin_query";
        nu-plugin-polars = nu-plugin "${pkgs.nushellPlugins.polars}/bin/nu_plugin_polars";
      };

    # Custom scripts
    file = {
      ".config/nushell/scripts/parse-env.nu" = {
        source = ./scripts/parse-env.nu;
      };
      # ".config/nushell/completions/jj.nu" = {
      #   source = ./completions/jj.nu;
      # };
      ".config/nushell/aliases/bat.nu" = {
        source = ./aliases/bat.nu;
      };
      ".config/nushell/aliases/git.nu" = {
        source = ./aliases/git.nu;
      };
      ".config/nushell/aliases/k8s.nu" = {
        source = ./aliases/k8s.nu;
      };
    };
  };

  programs.carapace = {
    enable = true;
    enableNushellIntegration = true;
  };

  programs.zoxide = {
    enable = true;
    enableNushellIntegration = true;
  };

  programs.fzf = {
    enable = true;
    # enableNushellIntegration = true;
  };

  programs.atuin = {
    enable = true;
    enableNushellIntegration = true;
  };

  programs.direnv = {
    enable = true;
    enableNushellIntegration = true;
    nix-direnv.enable = true;
  };

  programs.starship = {
    enable = true;
    enableNushellIntegration = true;
    settings = {
      add_newline = true;

      format = lib.concatStrings [
        "$username"
        "$hostname"
        "$directory"
        "$git_branch"
        "$git_state"
        "$git_status"
        "$cmd_duration"
        "$line_break"
        "$python"
        "$character"
      ];

      directory.style = "blue";

      character = {
        success_symbol = "[❯](purple)";
        error_symbol = "[❯](red)";
        vimcmd_symbol = "[❮](green)";
      };

      git_branch = {
        format = "[$branch]($style)";
        style = "bright-black";
      };

      git_status = {
        format = "[[(*$conflicted$untracked$modified$staged$renamed$deleted)](218) ($ahead_behind$stashed)]($style)";
        style = "cyan";
        conflicted = "";
        untracked = "";
        modified = "";
        staged = "";
        renamed = "";
        deleted = "";
        stashed = "≡";
      };

      git_state = {
        format = "([$state( $progress_current/$progress_total)]($style)) ";
        style = "bright-black";
      };

      cmd_duration = {
        format = "[$duration]($style) ";
        style = "yellow";
      };

      python = {
        format = "[$virtualenv]($style) ";
        style = "bright-black";
      };
    };
  };
}
