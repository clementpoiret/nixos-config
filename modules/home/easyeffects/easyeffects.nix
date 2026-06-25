{ hostFacts, lib, ... }:
let
  easyeffects = hostFacts.home.easyeffects or { };
  framework16Presets = easyeffects.framework16Presets or false;
in
{
  services.easyeffects = lib.mkIf (easyeffects.enable or false) {
    enable = true;
    preset = "none";
  };

  xdg.configFile = {
    # For defaults
    "easyeffects/output/none.json".text = # json
      ''
        {
          "output": {
              "blocklist": [],
              "plugins_order": []
          }
        }
      '';

    # Noise reduction and equalizer
    "easyeffects/input/tuned_mic.json".source = ./tuned_mic.json;
  }
  // lib.optionalAttrs framework16Presets {
    # Framework 16
    "easyeffects/output/easyeffects_fw16.json".source = ./easyeffects_fw16.json;
    "easyeffects/output/framework16-filters-WITHOUT-compression.json".source =
      ./framework16-filters-WITHOUT-compression.json;
    "easyeffects/output/framework16-filters-compression.json".source =
      ./framework16-filters-compression.json;
    "easyeffects/output/framework16-filters-lots-of-compression-and-bass.json".source =
      ./framework16-filters-lots-of-compression-and-bass.json;
  };
}
