{ inputs, ... }:
{
  imports = [ inputs.pi.homeModules.default ];

  # programs.pi.coding-agent = {
  #   enable = true;
  # };
}
