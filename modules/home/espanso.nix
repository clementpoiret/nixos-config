{ pkgs, ... }:
{
  # HACK: Current Espanso is broken on wayland because of missing perms.
  # A `espanso-fix` flake is used to allow input access of espanso.
  # TODO: Remove once fixed. Relevant PRs:
  # - https://github.com/NixOS/nixpkgs/pull/328890

  # WARNING: You'll need to run the following commands to have the complete
  # setup:
  # espanso install basic-emojis
  # espanso install lorem
  # espanso install greek-letters-improved
  # espanso install math-symbols
  # espanso install combining-characters

  services.espanso = {
    enable = true;
    package = pkgs.espanso-wayland;

    matches = {
      # Override default bindings
      base = {
        matches = [
          {
            trigger = ":date";
            replace = "{{mydate}}";
            vars = [
              {
                name = "mydate";
                type = "date";
                params.format = "%m-%d-%Y";
              }
            ];
          }
        ];
      };

      default = {
        matches = [

          # Auto close brackets, quotes and formatting modifiers, and put cursor in center
          {
            trigger = ":((";
            replace = "($|$)";
          }
          {
            trigger = ":[[";
            replace = "[$|$]";
          }
          {
            trigger = ":{{";
            replace = "{$|$}";
          }
          {
            trigger = ":<<";
            replace = "<$|$>";
          }
          {
            trigger = ":``";
            replace = "`$|$`";
          }
          {
            trigger = ":'";
            replace = "'$|$'";
          }
          {
            trigger = ":\"";
            replace = "\"$|$\"";
          }
          {
            trigger = ":__";
            replace = "_$|$_";
          }
          {
            trigger = ":**";
            replace = "*$|$*";
          }
        ];
      };
    };
  };
}
