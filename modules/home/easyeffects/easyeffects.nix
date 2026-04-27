{ host, lib, ... }:
{
  services.easyeffects = lib.mkIf (host == "laptop") {
    enable = true;
    preset = "none";
  };

  # For defaults
  xdg.configFile."easyeffects/output/none.json".text = # json
    ''
      {
        "output": {
            "blocklist": [],
            "plugins_order": []
        }
      }
    '';

  # Framework 16
  xdg.configFile."easyeffects/output/easyeffects_fw16.json".source = ./easyeffects_fw16.json;
  xdg.configFile."easyeffects/output/framework16-filters-WITHOUT-compression.json".source =
    ./framework16-filters-WITHOUT-compression.json;
  xdg.configFile."easyeffects/output/framework16-filters-compression.json".source =
    ./framework16-filters-compression.json;
  xdg.configFile."easyeffects/output/framework16-filters-lots-of-compression-and-bass.json".source =
    ./framework16-filters-lots-of-compression-and-bass.json;

  # Noise reduction and equalizer
  xdg.configFile."easyeffects/input/tuned_mic.json".source = ./tuned_mic.json;
}
