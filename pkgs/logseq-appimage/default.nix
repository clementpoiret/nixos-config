{
  lib,
  fetchurl,
  appimageTools,
  makeWrapper,
}:

let
  pname = "logseq-appimage";
  version = "2.0.1";

  src = fetchurl {
    url = "https://github.com/logseq/logseq/releases/download/${version}/Logseq-linux-x86_64-${version}.AppImage";
    hash = "sha256-Sd42cHizdnD+vbmH5WK3Xe4eGulsKL+4c4d5xCKX3Qw=";
  };

  appimageContents = appimageTools.extract {
    inherit pname version src;
  };
in
appimageTools.wrapType2 {
  inherit pname version src;

  nativeBuildInputs = [ makeWrapper ];

  extraInstallCommands = ''
    install -m 444 -D ${appimageContents}/*.desktop $out/share/applications/${pname}.desktop

    # Forcefully overwrite the Exec and Icon lines to guarantee they match our Nix configuration.
    # We use %U to allow Logseq to handle logseq:// URIs properly.
    sed -i 's|^Exec=.*|Exec=${pname} %U|' $out/share/applications/${pname}.desktop
    sed -i 's|^Icon=.*|Icon=logseq|' $out/share/applications/${pname}.desktop
      
    # Copy the icons out of the AppImage into the Nix store
    cp -r ${appimageContents}/usr/share/icons $out/share

    # Keep Logseq's self-installed CLI launcher inside the AppImage FHS environment.
    wrapProgram $out/bin/${pname} --set APPIMAGE $out/bin/${pname}
    makeWrapper $out/bin/${pname} $out/bin/logseq \
      --set ELECTRON_RUN_AS_NODE 1 \
      --add-flags ${appimageContents}/resources/app.asar/js/logseq-cli.js
  '';

  meta = with lib; {
    description = "A privacy-first, open-source platform for knowledge management and collaboration";
    homepage = "https://logseq.com/";
    license = licenses.agpl3Plus;
    platforms = [ "x86_64-linux" ];
    mainProgram = "logseq-appimage";
  };
}
