{ ... }:
{
  programs.fuzzel = {
    enable = true;
    settings = {
      main = {
        line-height = 25;
        fields = "name,generic,comment,categories,filename,keywords";
        terminal = "ghostty";
        prompt = "' ➜  '";
        layer = "top";
        lines = 10;
        width = 35;
        horizontal-pad = 25;
        inner-pad = 5;
        launch-prefix = "runapp";
      };
      border = {
        radius = 12;
        width = 4;
      };
    };
  };
}
