{ pkgs, ... }:
{
  programs.tmux = {
    enable = true;

    aggressiveResize = true;
    baseIndex = 1;
    disableConfirmationPrompt = true;
    keyMode = "vi";
    newSession = true;
    secureSocket = true;
    shell = "${pkgs.nushell}/bin/nu";
    shortcut = "a";
    terminal = "xterm-256color";
    mouse = true;

    plugins = with pkgs.tmuxPlugins; [
      better-mouse-mode
      catppuccin
      fingers
      sensible
      tmux-floax
      yank
    ];

    extraConfig = ''
      set -ga terminal-overrides ",*256col*:Tc"

      # Use Alt-arrow keys without prefix key to switch panes
      bind -n M-Left select-pane -L
      bind -n M-Right select-pane -R
      bind -n M-Up select-pane -U
      bind -n M-Down select-pane -D

      # Shift Alt vim keys to switch windows
      bind -n M-H previous-window
      bind -n M-L next-window

      # keybindings
      bind-key -T copy-mode-vi v send-keys -X begin-selection
      bind-key -T copy-mode-vi C-v send-keys -X rectangle-toggle
      bind-key -T copy-mode-vi y send-keys -X copy-selection-and-cancel
      bind-key r new-window -c "#{pane_current_path}" -n "REPL"

      bind '"' split-window -v -c "#{pane_current_path}"
      bind % split-window -h -c "#{pane_current_path}"
      bind c new-window -c "#{pane_current_path}"
    '';
  };
}
