{
  overlay =
    final: prev:
    let
      dirContents = builtins.readDir ./.;
      genPackage = name: {
        inherit name;
        value = final.callPackage (./. + "/${name}") { };
      };
      names = builtins.filter (
        name: dirContents.${name} == "directory" && builtins.pathExists (./. + "/${name}/default.nix")
      ) (builtins.attrNames dirContents);
    in
    builtins.listToAttrs (map genPackage names);
}
