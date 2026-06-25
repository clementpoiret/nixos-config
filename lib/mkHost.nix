{
  customOverlays,
  inputs,
  nixpkgs,
  self,
  stylix,
  system,
  username,
}:
{
  extraModules ? [ ],
  host,
  hostFacts ? null,
}:
let
  hostPath = ../hosts + "/${host}";
  facts = if hostFacts == null then import (hostPath + "/facts.nix") else hostFacts;
in
nixpkgs.lib.nixosSystem {
  inherit system;

  modules = [
    { nixpkgs.overlays = customOverlays; }
    hostPath
    stylix.nixosModules.stylix
  ]
  ++ extraModules;

  specialArgs = {
    inherit
      self
      inputs
      username
      host
      ;
    hostFacts = facts;
  };
}
