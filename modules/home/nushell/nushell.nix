{ host, inputs, lib, pkgs, ... }:
{
  programs.nushell = {
    enable = true;

    configFile.source = ./config.nu;
    envFile.source = ./env.nu;

    extraConfig = ''
      def nix-clean [] {
        sudo nix-collect-garbage
        sudo nix-collect-garbage -d
        sudo rm /nix/var/nix/gcroots/auto/*
        nix-collect-garbage
        nix-collect-garbage -d
      }

      def gcma [msg] {
        git add --all
        git commit -m $msg
      }
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
      ns = "nix-shell --run nu";
      nix-shell = "nix-shell --run nu";
      nix-switch = "sudo nixos-rebuild switch --flake ~/nixos-config#${host}";
      nix-switchu = "sudo nixos-rebuild switch --upgrade --flake ~/nixos-config#${host}";
      nix-flake-update = "sudo nix flake update ~/nixos-config#";

      # Git
      ga = "git add";
      gaa = "git add --all";
      gs = "git status";
      gb = "git branch";
      gm = "git merge";
      gpl = "git pull";
      gplo = "git pull origin";
      gps = "git push";
      gpst = "git push --follow-tags";
      gpso = "git push origin";
      gc = "git commit";
      gcm = "git commit -m";
      gtag = "git tag -ma";
      gch = "git checkout";
      gchb = "git checkout -b";
      gcoe = "git config user.email";
      gcon = "git config user.name";

      # python
      piv = "python -m venv .venv";
      # psv = "source .venv/bin/activate";

      # custom tools
      lakectl = "/home/clementpoiret/bin/lakectl";
      emacs = "emacsclient -c -a 'emacs'";
      doom = "~/.config/emacs/bin/doom";

      # to fix std lib issues
      obsidian = "with-env { LD_LIBRARY_PATH: $env.NIX_LD_LIBRARY_PATH } { obsidian }";
    };
  };

  home = {
    packages = with pkgs; [
      inputs.nu_plugin_bash_env.packages.${system}.default
      jq
    ];

    activation =
      let
        nu-plugin = path: lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          run ${pkgs.nushell}/bin/nu --no-config-file --no-history --no-std-lib -c 'plugin add --plugin-config ~/.config/nushell/plugin.msgpackz ${path}'
        '';
      in
      {
        nu-plugin-bash-env = nu-plugin "${inputs.nu_plugin_bash_env}/nu_plugin_bash_env";
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
