{ ... }:
{
  services.dunst = {
    enable = false;

    settings = {
      global = {
        follow = "mouse";

        width = 300;
        height = "(0,300)";
        offset = "(10,10)";

        corner_radius = 16;
      };

      "filter-low" = {
        msg_urgency = "low";
        skip_display = true;
      };

      "filter-normal" = {
        msg_urgency = "normal";
        skip_display = true;
      };
    };
  };
}
