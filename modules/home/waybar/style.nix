{ lib, ... }:
{
  programs.waybar.style =
    lib.mkAfter # css
      ''
        * {
          border: none;
          padding: 0;
          margin: 0;
          border-radius: 0px;
          font-weight: 500;
        }

        window#waybar {
          margin: 5px 0;
          font-weight: 500;
        }

        .modules-left #workspaces {
          border-radius: 32px;
          margin: 5px;
        }
        .modules-left #workspaces button {
          background: @base02;
          margin: 0px 5px;
          padding: 0px 10px;
          border-bottom: 0px solid @base02;
          border-radius: 32px;
          transition: all 0.5s cubic-bezier(0.33, 1.0, 0.68, 1.0); /* easeInOutCubic */
        }
        .modules-left #workspaces button.active {
          background: @base02;
          border: 1px solid rgba(0, 0, 0, 0);
          border-bottom: 0px solid @base02;
          border-radius: 32px;
          padding: 0rem 1rem;
        }
        .modules-left #workspaces button.empty {
          background: @base02;
          border-bottom: 0px solid @base02;
          border-radius: 32px;
        }
        .modules-left #workspaces button:hover {
          background: @base03;
          border-bottom: 0px solid @base03;
          border-radius: 32px;
          box-shadow: none;
          text-shadow: none;
          padding: 0rem 1rem;
        }

        #power-profiles-daemon,
        #custom-suspend,
        #custom-hyprsunset,
        #custom-fancontrol,
        #custom-launcher,
        #custom-power,
        #custom-weather {
            border-radius: 1rem;
            padding: 0.5rem;
            margin: 5px 0;
        }

        #custom-launcher {
            font-size: 16px;
            font-weight: 500;
        }
      '';
}
