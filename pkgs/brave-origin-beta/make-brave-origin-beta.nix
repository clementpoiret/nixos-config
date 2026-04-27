{
  lib,
  stdenv,
  fetchurl,
  buildPackages,
  alsa-lib,
  at-spi2-atk,
  at-spi2-core,
  atk,
  cairo,
  cups,
  dbus,
  dpkg,
  expat,
  fontconfig,
  freetype,
  gdk-pixbuf,
  glib,
  adwaita-icon-theme,
  gsettings-desktop-schemas,
  gtk3,
  gtk4,
  qt6,
  libx11,
  libxscrnsaver,
  libxcomposite,
  libxcursor,
  libxdamage,
  libxext,
  libxfixes,
  libxi,
  libxrandr,
  libxrender,
  libxtst,
  libdrm,
  libkrb5,
  libuuid,
  libxkbcommon,
  libxshmfence,
  libgbm,
  nspr,
  nss,
  pango,
  pipewire,
  snappy,
  udev,
  wayland,
  xdg-utils,
  coreutils,
  libxcb,
  zlib,

  # Darwin dependencies
  unzip,
  makeWrapper,

  # command line arguments which are always set e.g "--disable-gpu"
  commandLineArgs ? "",

  # Necessary for USB audio devices.
  pulseSupport ? stdenv.hostPlatform.isLinux,
  libpulseaudio,

  # For GPU acceleration support on Wayland (without the lib it doesn't seem to work)
  libGL,

  # For video acceleration via VA-API (--enable-features=AcceleratedVideoDecodeLinuxGL,AcceleratedVideoEncoder)
  libvaSupport ? stdenv.hostPlatform.isLinux,
  libva,
  enableVideoAcceleration ? libvaSupport,

  # For Vulkan support (--enable-features=Vulkan); disabled by default as it seems to break VA-API
  vulkanSupport ? false,
  addDriverRunpath,
  enableVulkan ? vulkanSupport,
}:

{
  pname,
  version,
  hash,
  url,
}:

let
  inherit (lib)
    optional
    optionals
    makeLibraryPath
    makeSearchPathOutput
    makeBinPath
    optionalString
    strings
    escapeShellArg
    ;

  deps = [
    alsa-lib
    at-spi2-atk
    at-spi2-core
    atk
    cairo
    cups
    dbus
    expat
    fontconfig
    freetype
    gdk-pixbuf
    glib
    gtk3
    gtk4
    libdrm
    libx11
    libGL
    libxkbcommon
    libxscrnsaver
    libxcomposite
    libxcursor
    libxdamage
    libxext
    libxfixes
    libxi
    libxrandr
    libxrender
    libxshmfence
    libxtst
    libuuid
    libgbm
    nspr
    nss
    pango
    pipewire
    udev
    wayland
    libxcb
    zlib
    snappy
    libkrb5
    qt6.qtbase
  ]
  ++ optional pulseSupport libpulseaudio
  ++ optional libvaSupport libva;

  rpath = makeLibraryPath deps + ":" + makeSearchPathOutput "lib" "lib64" deps;
  binpath = makeBinPath deps;

  enableFeatures =
    optionals enableVideoAcceleration [
      "AcceleratedVideoDecodeLinuxGL"
      "AcceleratedVideoEncoder"
    ]
    ++ optional enableVulkan "Vulkan";

  disableFeatures = [
    "OutdatedBuildDetector"
  ] # disable automatic updates
  # The feature disable is needed for VAAPI to work correctly: https://github.com/brave/brave-browser/issues/20935
  ++ optionals enableVideoAcceleration [ "UseChromeOSDirectVideoDecoder" ];

  # Paths inside the .deb — verified by running: dpkg-deb -c brave-origin-beta_*_amd64.deb
  braveDir = "brave-origin-beta"; # /opt/brave.com/<this>/
  braveWrapper = "brave-origin-beta"; # wrapper script name inside braveDir
  braveBin = "brave"; # main ELF binary name inside braveDir
  desktopFileBase = "brave-origin-beta"; # .desktop file stem
  desktopFileId = "com.brave.Origin.beta"; # freedesktop app-id .desktop stem
  gnomeControlXml = "brave-origin-beta"; # gnome-control-center default-apps XML stem

  # macOS app bundle name — verify against the .zip contents
  darwinAppName = "Brave Browser Origin Beta";
in
stdenv.mkDerivation {
  inherit pname version;

  src = fetchurl {
    inherit url hash;
  };

  dontConfigure = true;
  dontBuild = true;
  dontPatchELF = true;
  doInstallCheck = stdenv.hostPlatform.isLinux;

  nativeBuildInputs =
    lib.optionals stdenv.hostPlatform.isLinux [
      dpkg
      # override doesn't preserve splicing https://github.com/NixOS/nixpkgs/issues/132651
      # Has to use `makeShellWrapper` from `buildPackages` even though `makeShellWrapper` from the inputs is spliced because `propagatedBuildInputs` would pick the wrong one because of a different offset.
      (buildPackages.wrapGAppsHook3.override { makeWrapper = buildPackages.makeShellWrapper; })
    ]
    ++ lib.optionals stdenv.hostPlatform.isDarwin [
      unzip
      makeWrapper
    ];

  buildInputs = lib.optionals stdenv.hostPlatform.isLinux [
    # needed for GSETTINGS_SCHEMAS_PATH
    glib
    gsettings-desktop-schemas
    gtk3
    gtk4

    # needed for XDG_ICON_DIRS
    adwaita-icon-theme
  ];

  installPhase =
    lib.optionalString stdenv.hostPlatform.isLinux ''
      runHook preInstall

      mkdir -p $out $out/bin

      cp -R usr/share $out
      cp -R opt/ $out/opt

      export BINARYWRAPPER=$out/opt/brave.com/${braveDir}/${braveWrapper}

      # Fix path to bash in $BINARYWRAPPER
      substituteInPlace $BINARYWRAPPER \
          --replace-fail /bin/bash ${stdenv.shell} \
          --replace-fail 'CHROME_WRAPPER' 'WRAPPER'

      ln -sf $BINARYWRAPPER $out/bin/${pname}

      for exe in $out/opt/brave.com/${braveDir}/{${braveBin},chrome_crashpad_handler}; do
          patchelf \
              --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" \
              --set-rpath "${rpath}" $exe
      done

      # Fix paths in desktop files
      substituteInPlace $out/share/applications/${desktopFileBase}.desktop \
          --replace-fail /usr/bin/${braveWrapper} $out/bin/${pname}

      # If a freedesktop app-id desktop file exists, patch it too
      if [ -f $out/share/applications/${desktopFileId}.desktop ]; then
        substituteInPlace $out/share/applications/${desktopFileId}.desktop \
            --replace-fail /usr/bin/${braveWrapper} $out/bin/${pname}
      fi

      if [ -f $out/share/gnome-control-center/default-apps/${gnomeControlXml}.xml ]; then
        substituteInPlace $out/share/gnome-control-center/default-apps/${gnomeControlXml}.xml \
            --replace-fail /opt/brave.com $out/opt/brave.com
      fi

      if [ -f $out/opt/brave.com/${braveDir}/default-app-block ]; then
        substituteInPlace $out/opt/brave.com/${braveDir}/default-app-block \
            --replace-fail /opt/brave.com $out/opt/brave.com
      fi

      # Correct icons location
      icon_sizes=("16" "24" "32" "48" "64" "128" "256")

      for icon in ''${icon_sizes[*]}
      do
          mkdir -p $out/share/icons/hicolor/$icon\x$icon/apps
          ln -s $out/opt/brave.com/${braveDir}/product_logo_$icon.png $out/share/icons/hicolor/$icon\x$icon/apps/${desktopFileBase}.png
      done

      # Replace xdg-settings and xdg-mime
      ln -sf ${xdg-utils}/bin/xdg-settings $out/opt/brave.com/${braveDir}/xdg-settings
      ln -sf ${xdg-utils}/bin/xdg-mime $out/opt/brave.com/${braveDir}/xdg-mime

      runHook postInstall
    ''
    + lib.optionalString stdenv.hostPlatform.isDarwin ''
      runHook preInstall

      mkdir -p $out/{Applications,bin}

      cp -r . "$out/Applications/${darwinAppName}.app"

      makeWrapper "$out/Applications/${darwinAppName}.app/Contents/MacOS/${darwinAppName}" $out/bin/${pname}

      runHook postInstall
    '';

  preFixup = lib.optionalString stdenv.hostPlatform.isLinux ''
    # Add command line args to wrapGApp.
    gappsWrapperArgs+=(
      --prefix LD_LIBRARY_PATH : ${rpath}
      --prefix PATH : ${binpath}
      --suffix PATH : ${
        lib.makeBinPath [
          xdg-utils
          coreutils
        ]
      }
      --set CHROME_WRAPPER ${pname}
      ${optionalString (enableFeatures != [ ]) ''
        --add-flags "--enable-features=${strings.concatStringsSep "," enableFeatures}\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+,WaylandWindowDecorations --enable-wayland-ime=true}}"
      ''}
      ${optionalString (disableFeatures != [ ]) ''
        --add-flags "--disable-features=${strings.concatStringsSep "," disableFeatures}"
      ''}
      --add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+--ozone-platform-hint=auto}}"
      ${optionalString vulkanSupport ''
        --prefix XDG_DATA_DIRS  : "${addDriverRunpath.driverLink}/share"
      ''}
      --add-flags ${escapeShellArg commandLineArgs}
    )
  '';

  installCheckPhase = ''
    # Bypass upstream wrapper which suppresses errors
    $out/opt/brave.com/${braveDir}/${braveBin} --version
  '';

  passthru.updateScript = ./update.sh;

  meta = {
    homepage = "https://brave.com/";
    description = "Brave Origin Beta — privacy-oriented browser (beta channel, Origin variant)";
    changelog =
      "https://github.com/brave/brave-browser/blob/master/CHANGELOG_DESKTOP.md#"
      + lib.replaceStrings [ "." ] [ "" ] version;
    longDescription = ''
      Brave Origin Beta is the beta-channel Origin variant of the Brave browser.
      It blocks the ads and trackers that slow you down, chew up your bandwidth,
      and invade your privacy.
    '';
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    license = lib.licenses.mpl20;
    maintainers = with lib.maintainers; [
      "clementpoiret"
    ];
    platforms = [
      "x86_64-linux"
      "aarch64-darwin"
      "x86_64-darwin"
    ];
    mainProgram = "brave-origin-beta";
  };
}
