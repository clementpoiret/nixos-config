{
  lib,
  fetchurl,
  appimageTools,
}:

let
  pname = "logseq-appimage";
  version = "0.10.15";

  src = fetchurl {
    url = "https://github.com/logseq/logseq/releases/download/${version}/Logseq-linux-x64-${version}.AppImage";
    sha256 = "sha256-i5EQUvSW1ix+8NT8nCs6mGH2B9xF7G4mB7vBhDJ7JdE=";
  };

  appimageContents = appimageTools.extractType2 {
    inherit pname version src;
  };
in
appimageTools.wrapType2 {
  inherit pname version src;

  extraInstallCommands = ''
    install -m 444 -D ${appimageContents}/*.desktop $out/share/applications/${pname}.desktop

    # Forcefully overwrite the Exec and Icon lines to guarantee they match our Nix configuration.
    # We use %U to allow Logseq to handle logseq:// URIs properly.
    sed -i 's|^Exec=.*|Exec=${pname} %U|' $out/share/applications/${pname}.desktop
    sed -i 's|^Icon=.*|Icon=logseq|' $out/share/applications/${pname}.desktop
      
    # Copy the icons out of the AppImage into the Nix store
    cp -r ${appimageContents}/usr/share/icons $out/share
  '';

  meta = with lib; {
    description = "A privacy-first, open-source platform for knowledge management and collaboration";
    homepage = "https://logseq.com/";
    license = licenses.agpl3Plus;
    platforms = [ "x86_64-linux" ];
    mainProgram = "logseq-appimage";
  };
}
