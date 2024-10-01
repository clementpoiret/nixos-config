{ hostname, config, pkgs, host, ... }: {
  programs.zsh = {
    enable = true;
    dotDir = ".config/zsh";
    antidote = {
      enable = true;
      plugins = [
        "belak/zsh-utils path:completion"
        "belak/zsh-utils path:editor"
        "belak/zsh-utils path:history"
        "belak/zsh-utils path:prompt"
        "belak/zsh-utils path:utility"
        "zdharma-continuum/fast-syntax-highlighting kind:defer"
        "zsh-users/zsh-autosuggestions"
        "zsh-users/zsh-completions"
      ];
    };
    initExtra = ''
      bindkey '^p' history-search-backward
      bindkey '^n' history-search-forward

      zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'

      eval "$(micromamba shell hook --shell zsh)"
    '';

    history = {
      expireDuplicatesFirst = true;
      ignoreDups = true;
      ignoreAllDups = true;
      ignoreSpace = true;
      extended = true;
      share = true;
      size = 10000;
      save = 10000;
    };

    shellAliases = {
      # Utils
      c = "clear";
      cd = "z";
      tt = "gtrash put";
      cat = "bat";
      nano = "micro";
      py = "python";
      icat = "kitten icat";
      dsize = "du -hs";
      findw = "grep -rl";
      pdf = "tdf";
      open = "xdg-open";

      ls = "lsd --group-directories-first";
      ll = "lsd -l --group-directories-first";
      la = "lsd -la --group-directories-first";
      tree = "lsd -l --group-directories-first --tree --depth=2";

      # Nixos
      cdnix = "cd ~/nixos-config && nvim ~/nixos-config";
      ns = "nix-shell --run zsh";
      nix-shell = "nix-shell --run zsh";
      nix-switch = "sudo nixos-rebuild switch --flake ~/nixos-config#${host}";
      nix-switchu =
        "sudo nixos-rebuild switch --upgrade --flake ~/nixos-config#${host}";
      nix-flake-update = "sudo nix flake update ~/nixos-config#";
      nix-clean =
        "sudo nix-collect-garbage && sudo nix-collect-garbage -d && sudo rm /nix/var/nix/gcroots/auto/* && nix-collect-garbage && nix-collect-garbage -d";

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
      gcma = "git add --all && git commit -m";
      gtag = "git tag -ma";
      gch = "git checkout";
      gchb = "git checkout -b";
      gcoe = "git config user.email";
      gcon = "git config user.name";

      # python
      piv = "python -m venv .venv";
      psv = "source .venv/bin/activate";

      # custom tools
      lakectl = "/home/clementpoiret/bin/lakectl";
      emacs = "emacsclient -c -a 'emacs'";

      # to fix std lib issues
      obsidian = "export LD_LIBRARY_PATH=$NIX_LD_LIBRARY_PATH; obsidian";
    };
  };

  programs.oh-my-posh = {
    enable = true;
    enableZshIntegration = true;
    enableNushellIntegration = false;
    settings = {
      "$schema" =
        "https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/main/themes/schema.json";
      version = 2;
      final_space = true;
      console_title_template = "{{ .Shell }} in {{ .Folder }}";
      blocks = [
        {
          type = "prompt";
          alignment = "left";
          newline = true;

          segments = [
            {
              type = "path";
              style = "plain";
              background = "transparent";
              foreground = "blue";
              properties.style = "full";
              template = "{{ .Path }}";
            }
            {
              type = "git";
              style = "plain";
              background = "transparent";
              foreground = "p:grey";
              template =
                " {{ .HEAD }}{{ if or (.Working.Changed) (.Staging.Changed) }}*{{ end }} <cyan>{{ if gt .Behind 0 }}⇣{{ end }}{{ if gt .Ahead 0 }}⇡{{ end }}</>";
              properties = {
                branch_icon = "";
                commit_icon = "@";
                fetch_status = true;
              };
            }
          ];
        }

        {
          type = "rprompt";
          overflow = "hidden";

          segments = [
            {
              type = "executiontime";
              style = "plain";
              background = "transparent";
              foreground = "yellow";
              template = "{{ .FormattedMs }}";
              properties.threshold = 5000;
            }
            {
              type = "python";
              style = "plain";
              background = "transparent";
              foreground = "p:grey";
              fetch_virtual_env = true;
              display_default = true;
              fetch_version = true;
            }
          ];
        }

        {
          type = "prompt";
          alignment = "left";
          newline = true;

          segments = [{
            type = "text";
            style = "plain";
            background = "transparent";
            foreground_templates = [
              "{{if gt .Code 0}}red{{end}}"
              "{{if eq .Code 0}}magenta{{end}}"
            ];
            template = "❯";
          }];
        }
      ];

      transient_prompt = {
        background = "transparent";
        foreground_templates =
          [ "{{if gt .Code 0}}red{{end}}" "{{if eq .Code 0}}magenta{{end}}" ];
        template = "❯ ";
      };

      secondary_prompt = {
        background = "transparent";
        foreground = "magenta";
        template = "❯❯ ";
      };

      palette.grey = "#6c6c6c";
    };
  };

  programs.zoxide = {
    enable = true;
    enableZshIntegration = true;
  };

  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
  };

  programs.atuin = {
    enable = true;
    enableZshIntegration = true;
  };
}
