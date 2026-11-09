{
  overlay =
    final: _prev:
    let
      dirContents = builtins.readDir ./.;
      genPackage = name: {
        inherit name;
        value = final.callPackage (./. + "/${name}") (
          if name == "brave" then
            {
              upstreamBrave =
                (final.callPackage (final.master.path + "/pkgs/applications/networking/browsers/brave") { }).brave;
            }
          else
            { }
        );
      };
      names = builtins.filter (
        name: dirContents.${name} == "directory" && builtins.pathExists (./. + "/${name}/default.nix")
      ) (builtins.attrNames dirContents);
    in
    builtins.listToAttrs (map genPackage names)
    // {
      proton-pass-beta = final.proton-pass.override { channel = "beta"; };
      protonmail-desktop-beta = final.protonmail-desktop.override { channel = "beta"; };
    };
}
