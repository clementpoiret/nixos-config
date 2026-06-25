{ pkgs, ... }:
{
  programs.fish = {
    enable = true;
    shellAbbrs = {
      # cd = "z";
      # cat = "bat";
    };
    shellAliases = {
      # utils
      c = "clear";
      cd = "z";
      tt = "gtrash put";
      cat = "bat";
      pdf = "tdf";

      ll = "ls -l";
      la = "ls -a";
      ldu = "ls -d";

      # nix
      cdnix = "cd ~/nixos-config";
      ns = "nom-shell --run fish";
      nix-shell = "nix-shell --run fish";
      nix-switch = "nh os switch";
      nix-update = "nh os switch --update";
      nix-clean = "nh clean all --keep 5";
      nix-search = "nh search";
      nix-test = "nh os test";
      nix-flake-update = "nix flake update ~/nixos-config#";
    };
    shellInit = ''
      # (Interactive-only variables like fish_greeting & fish_escape_delay_ms moved to interactiveShellInit)
    '';
    shellInitLast = ''
      devenv hook fish | source
    '';
    interactiveShellInit = ''
      fish_vi_key_bindings
      set fish_greeting # Disable greeting
      set -g fish_escape_delay_ms 500

      # FZF: Apply vim-style movement keys globally to all fzf instances
      set -gx FZF_DEFAULT_OPTS "
        --bind=ctrl-j:down
        --bind=ctrl-k:up
        --bind=ctrl-d:half-page-down
        --bind=ctrl-u:half-page-up
        --bind=enter:accept
        --color=fg:#908caa,bg:#191724,hl:#ebbcba
        --color=fg+:#e0def4,bg+:#26233a,hl+:#ebbcba
        --color=border:#403d52,header:#31748f,gutter:#191724
        --color=spinner:#f6c177,info:#9ccfd8
        --color=pointer:#c4a7e7,marker:#eb6f92,prompt:#908caa"

      # Reuse same bindings for completion integrations (fzf.fish, etc.)
      set -gx FZF_COMPLETE_OPTS $FZF_DEFAULT_OPTS
    '';
    functions.fish_user_key_bindings.body = ''
      # Ctrl+B -> fuzzy search existing fish key bindings (overrides default backward-char)
      bind ctrl-b fun_fzf_bindings
      bind -M insert ctrl-b fun_fzf_bindings
      bind -M visual ctrl-b fun_fzf_bindings

      # Change fzf.fish keybindings (fzf_configure_bindings needs to be called at least to get default bindings)
      # help:   fzf_configure_bindings --h
      if functions -q fzf_configure_bindings
        fzf_configure_bindings --processes=ctrl-p --directory=ctrl-f
      end

      # Copy current command line to clipboard
      # Ctrl+Y in insert mode
      bind -M insert ctrl-y fun_copy_commandline_to_clipboard
      # Vim-like yy in normal (default) mode
      bind -M default 'yy' 'fun_copy_commandline_to_clipboard'

      # Ctrl+O -> fuzzy pick a file and insert (works in normal/insert/visual).
        bind ctrl-o fun_fzf_file_open
        bind -M insert ctrl-o fun_fzf_file_open
        bind -M visual ctrl-o fun_fzf_file_open
    '';
    functions.fun_fzf_bindings.body = ''
      # Fuzzy search current fish key bindings using fzf
      if not type -q fzf
        echo "fzf not found in PATH (required for fun_fzf_bindings)" >&2
        return 127
      end

      # Collect bindings, strip leading 'bind ' and let user pick
      set -l selection (bind | sed 's/^bind \\+//' | fzf \
        --prompt="fish bindings> " \
        --height=60% \
        --reverse \
        --border \
        --exit-0 \
        --preview 'echo {}' )

      if test -n "$selection"
        set_color --bold green
        echo Selected binding:
        set_color normal
        echo "$selection"
        # Optionally: parse key + command
        # echo "$selection" | read -l key rest; echo "Key: $key"; echo "Command: $rest"
      end
    '';
    functions.fun_copy_commandline_to_clipboard.body = ''
      set -l line (commandline)
      if test -z "$line"
        return 0
      end

      if type -q wl-copy
        printf '%s' "$line" | wl-copy
      else if type -q xclip
        printf '%s' "$line" | xclip -selection clipboard
      else if type -q xsel
        printf '%s' "$line" | xsel --clipboard --input
      else if type -q pbcopy
        printf '%s' "$line" | pbcopy
      else
        printf 'No clipboard tool (wl-copy/xclip/xsel/pbcopy) found\n' >&2
        return 1
      end
    '';
    functions.fun_fzf_file_open.body = ''
      # Build file list command (fd preferred)
      set -l list_cmd ""
      if type -q fd
        set list_cmd "fd --type f --hidden --follow --exclude .git"
      else
        set list_cmd "find . -type f -not -path '*/.git/*'"
      end

      # Invoke picker with smart preview (images via chafa, text via bat)
      set -l file (eval $list_cmd | fzf \
        --prompt="file> " \
        --height=80% \
        --reverse \
        --border \
        --preview 'if file --mime-type {} | grep -qE "image/(png|jpeg|jpg|gif|bmp|webp|svg)"; then
            chafa --size="$FZF_PREVIEW_COLUMNS"x"$FZF_PREVIEW_LINES" --animate=false {} 2>/dev/null;
          else
            bat --style=numbers --color=always --line-range=:300 {} 2>/dev/null;
          fi' \
        --preview-window=right,50%:wrap )

      test -n "$file"; or return 0

      # Always properly escape the path (handles spaces and special chars)
      set -l insert_path (string escape -- "$file")
      commandline -i $insert_path
      commandline -f repaint
    '';
    # shellInit = ''
    #   set fish_greeting # Disable greeting
    # '';
    plugins = [
      {
        name = "autopair";
        src = pkgs.fishPlugins.autopair.src;
      }
      {
        name = "colored-man-pages";
        src = pkgs.fishPlugins.colored-man-pages.src;
      }
      {
        name = "fzf-fish";
        src = pkgs.fishPlugins.fzf-fish.src;
      }
      {
        name = "hydro";
        src = pkgs.fishPlugins.hydro.src;
      }
      {
        name = "sponge";
        src = pkgs.fishPlugins.sponge.src;
      }
      # {
      #   name = "tide";
      #   src = pkgs.fishPlugins.tide.src;
      # }
    ];
  };

  home.file.".config/fish/conf.d/sponge.fish".text = ''
    # Configure fish sponge plugin delay
    set -U sponge_delay 5
  '';

  programs.atuin = {
    enable = true;
    settings = {
      store-failed = false;
    };
    enableFishIntegration = false;
  };
  programs.broot = {
    enable = true;
    enableFishIntegration = true;
  };
  programs.carapace = {
    enable = true;
    enableFishIntegration = true;
  };
  programs.direnv = {
    enable = true;
    enableFishIntegration = true;
    nix-direnv.enable = true;
  };
  programs.fzf = {
    enable = true;
    enableFishIntegration = false;
  };
  programs.zoxide = {
    enable = true;
    enableFishIntegration = true;
  };
}
