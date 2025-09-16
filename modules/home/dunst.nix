{ ... }:
{
  services.dunst = {
    enable = true;

    settings = {
      global = {
        follow = "mouse";

        width = 300;
        height = "(0,300)";
        offset = "(10,10)";

        corner_radius = 16;
      };
    };
  };
}
