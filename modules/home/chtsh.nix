{ pkgs, ... }:
let
  bashScript = # sh
    ''
      #!/usr/bin/env bash
      selected=`cat ~/.tmux-cht-languages ~/.tmux-cht-commands | fzf`
      if [[ -z $selected ]]; then
          exit 0
      fi

      read -p "Enter Query: " query

      if grep -qs "$selected" ~/.tmux-cht-languages; then
          query=`echo $query | tr ' ' '+'`
          tmux neww bash -c "echo \"curl cht.sh/$selected/$query/\" & curl cht.sh/$selected/$query & while [ : ]; do sleep 1; done"
      else
          tmux neww bash -c "curl -s cht.sh/$selected~$query | less"
      fi
    '';

  tmux-cht = pkgs.writeScriptBin "tmux-cht" bashScript;

  languages = ''
    bash
    c
    cpp
    css
    dart
    elixir
    elm
    fortran
    golang
    html
    javascript
    julia
    latex
    lua
    nu
    python
    python3
    rust
    typescript
    zig
  '';

  commands = ''
    awk
    chmod
    chown
    docker
    find
    grep
    jq
    lsof
    man
    podman    
    ps
    sed
    ssh
    tar
    tldr
    tmux
    xargs
  '';
in
{
  home.packages = [ tmux-cht ];
  home.file = {
    ".tmux-cht-languages".text = languages;
    ".tmux-cht-commands".text = commands;
  };
}
