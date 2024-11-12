{ config, host, inputs, lib, pkgs, ... }:
let
  home = config.home.homeDirectory;
  profileDirectory = config.home.profileDirectory;
in {
  programs.nushell = {
    enable = true;

    configFile.source = ./config.nu;
    envFile.source = ./env.nu;

    extraConfig = ''
      # Source the conda script to activate micromamba envs
      use conda.nu [activate deactivate]

      # Jujutsu
      source ($nu.default-config-dir | path join 'completions/jj.nu')

      # Program aliases
      use ($nu.default-config-dir | path join 'aliases/bat.nu') *
      use ($nu.default-config-dir | path join 'aliases/git.nu') *
      use ($nu.default-config-dir | path join 'aliases/k8s.nu') *

      # gitui ssh fix
      # see https://github.com/extrawurst/gitui/issues/495
      def sshgitui [] {
        do --env {
          let ssh_agent_file = (
            $nu.temp-path | path join $"ssh-agent-($env.USER?).nuon"
          )

          if ($ssh_agent_file | path exists) {
            let ssh_agent_env = open ($ssh_agent_file)
            if ($"/proc/($ssh_agent_env.SSH_AGENT_PID)" | path exists) {
              load-env $ssh_agent_env
              return
            } else {
              rm $ssh_agent_file
            }
          }

          let ssh_agent_env = ^ssh-agent -c
            | lines
            | first 2
            | parse "setenv {name} {value};"
            | transpose --header-row
            | into record
          load-env $ssh_agent_env
          $ssh_agent_env | save --force $ssh_agent_file
          }
        ssh-add ~/.ssh/id_ed25519
        gitui
      }
      alias g = sshgitui
    '';

    extraEnv = ''
      # Source /etc/set-environment to get environment variables
      bash-env /etc/set-environment | load-env

      # Same thing but for session variables set using home-manager
      bash-env ${profileDirectory}/etc/profile.d/hm-session-vars.sh | load-env

      # Fixes Micromamba and Aider
      $env.GIT_PYTHON_GIT_EXECUTABLE = "${profileDirectory}/bin/git"

      # Misc API Keys from SOPS
      $env.ANTHROPIC_API_KEY = ^cat /run/user/1000/secrets/api_keys/anthropic
    '';

    shellAliases = {
      # Utils
      c = "clear";
      cd = "z";
      tt = "gtrash put";
      cat = "bat";
      nano = "micro";
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

      # python
      piv = "python -m venv .venv";
      # psv = "source .venv/bin/activate";

      # custom tools
      lakectl = "/home/clementpoiret/bin/lakectl";
      emacs = "emacsclient -c -a 'emacs'";

      # to fix std lib issues
      obsidian =
        "with-env { LD_LIBRARY_PATH: $env.NIX_LD_LIBRARY_PATH } { obsidian }";
    };
  };

  home = {
    packages = with pkgs; [
      flake.nu_plugin_bash_env
      jq
      nufmt
      nushellPlugins.query
      nushellPlugins.polars
    ];

    activation = let
      nu-plugin = path:
        lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          run ${pkgs.nushell}/bin/nu --no-config-file --no-history --no-std-lib -c 'plugin add --plugin-config ~/.config/nushell/plugin.msgpackz ${path}'
        '';
    in {
      nu-plugin-bash-env =
        nu-plugin "${pkgs.flake.nu_plugin_bash_env}/bin/nu_plugin_bash_env";
      nu-plugin-query = nu-plugin "${pkgs.nushellPlugins.query}/bin/nu_plugin_query";
      nu-plugin-polars = nu-plugin "${pkgs.nushellPlugins.polars}/bin/nu_plugin_polars";
    };

    # Custom scripts
    file = {
      ".config/nushell/scripts/conda.nu" = { source = ./scripts/conda.nu; };
      ".config/nushell/completions/jj.nu" = { source = ./completions/jj.nu; };
      ".config/nushell/aliases/bat.nu" = { source = ./aliases/bat.nu; };
      ".config/nushell/aliases/git.nu" = { source = ./aliases/git.nu; };
      ".config/nushell/aliases/k8s.nu" = { source = ./aliases/k8s.nu; };
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
        format =
          "[[(*$conflicted$untracked$modified$staged$renamed$deleted)](218) ($ahead_behind$stashed)]($style)";
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
