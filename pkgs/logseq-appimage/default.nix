{
  lib,
  fetchurl,
  appimageTools,
  asar,
  bash,
  makeWrapper,
  patchelf,
  runCommand,
  stdenv,
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
    postExtract = ''
      ${patchelf}/bin/patchelf --set-interpreter ${stdenv.cc.bintools.dynamicLinker} "$out/logseq"
    '';
  };

  # Reuse the AppImage FHS library closure without its bubblewrap launcher.
  # The extracted Electron payload runs correctly against this immutable
  # symlink tree and therefore does not need runtime mounts or ldconfig.
  fhsEnv = (appimageTools.wrapType2 { inherit pname version src; }).fhsenv;
in
runCommand "${pname}-${version}"
  {
    nativeBuildInputs = [
      asar
      makeWrapper
    ];

    passthru = {
      inherit appimageContents fhsEnv;
    };

    meta = with lib; {
      description = "A privacy-first, open-source platform for knowledge management and collaboration";
      homepage = "https://logseq.com/";
      license = licenses.agpl3Plus;
      platforms = [ "x86_64-linux" ];
      mainProgram = "logseq-appimage";
    };
  }
  ''
    install -d $out/bin
    install -m 444 -D ${appimageContents}/*.desktop $out/share/applications/${pname}.desktop

    # Forcefully overwrite the Exec and Icon lines to guarantee they match our Nix configuration.
    # We use %U to allow Logseq to handle logseq:// URIs properly.
    sed -i 's|^Exec=.*|Exec=${pname} %U|' $out/share/applications/${pname}.desktop
    sed -i 's|^Icon=.*|Icon=logseq|' $out/share/applications/${pname}.desktop
      
    # Copy the icons out of the AppImage into the Nix store
    cp -r ${appimageContents}/usr/share/icons $out/share

    # The CLI resolves its bundled skill relative to its entry point, while
    # electron-builder installs the skill next to app.asar. Extract the CLI
    # runtime next to a copy of that skill so all skill commands can find it.
    install -d $out/share/logseq/js
    (
      cd $out/share/logseq/js
      asar extract-file ${appimageContents}/resources/app.asar js/logseq-cli.js
      asar extract-file ${appimageContents}/resources/app.asar js/db-worker-node.js
    )
    install -m 444 -D \
      ${appimageContents}/resources/.agents/skills/logseq-cli/SKILL.md \
      $out/share/logseq/js/.agents/skills/logseq-cli/SKILL.md

    # Launch the extracted payload directly. The FHS library symlink tree is
    # immutable and requires neither a mount namespace nor runtime ldconfig.
    makeWrapper ${bash}/bin/bash $out/bin/${pname} \
      --add-flags ${appimageContents}/AppRun \
      --set APPDIR ${appimageContents} \
      --set APPIMAGE $out/bin/${pname} \
      --prefix LD_LIBRARY_PATH : ${fhsEnv}/usr/lib64 \
      --run "if [ \"\$#\" -gt 0 ] && [ \"\$1\" = '${appimageContents}/resources/app.asar/js/logseq-cli.js' ]; then shift; set -- '$out/share/logseq/js/logseq-cli.js' \"\$@\"; fi"
    makeWrapper $out/bin/${pname} $out/bin/logseq \
      --set ELECTRON_RUN_AS_NODE 1 \
      --add-flags $out/share/logseq/js/logseq-cli.js
  ''
