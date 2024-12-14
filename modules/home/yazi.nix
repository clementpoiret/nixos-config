{ pkgs, ... }:
{
  programs.yazi = {
    enable = true;
    enableZshIntegration = true;
    enableNushellIntegration = true;

    settings.manager = {
      sort_by = "mtime";
      sort_dir_first = true;
      sort_reverse = true;
      linemode = "size";
    };

    keymap = {
      manager.prepend_keymap = [
        {
          run = "shell '$SHELL' --block --confirm";
          on = [ "<C-s>" ];
        }
        {
          run = ''shell 'ripdrag "$@" -x 2>/dev/null &' --confirm'';
          on = [ "<C-n>" ];
        }
        {
          run = [
            "yank"
            ''
              shell --confirm 'for path in "$@"; do echo "file://$path"; done | wl-copy -t text/uri-list'
            ''
          ];
          on = [ "y" ];
        }
      ];
    };
  };

  home.packages = (with pkgs; [ ripdrag ]);
}
