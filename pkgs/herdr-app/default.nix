# Adapted from nixpkgs PR #581031; replace with upstream's package once herdr ships a flake.
{
  lib,
  stdenv,
  rustPlatform,
  fetchFromGitHub,
  zig_0_16,
  pkg-config,
  clang,
  bash,
  coreutils,
  curl,
  git,
  makeDesktopItem,
  copyDesktopItems,
  fontconfig,
  makeFontsConf,
  dejavu_fonts,
  freetype,
  libxcb,
  libxkbcommon,
  libGL,
  wayland,
  vulkan-loader,
  zstd,
  mesa,
  writableTmpDirAsHomeHook,
  xdg-utils,
  herdr-core,
  versionCheckHook,
}:
let
  # wgpu (Vulkan, with OpenGL as fallback) and the Wayland backend load these with dlopen.
  dlopenLibs = [
    libGL
    vulkan-loader
    wayland
  ];
in
rustPlatform.buildRustPackage (finalAttrs: {
  pname = "herdr-app";
  version = "0.1.13";

  __structuredAttrs = true;

  src = fetchFromGitHub {
    owner = "herdrdev";
    repo = "herdr-app";
    tag = "v${finalAttrs.version}";
    fetchSubmodules = true;
    hash = "sha256-vM25epPf+4Y+gUj/2BTQ6fpOIBI7T5UddFdlMAr6X0o=";
  };

  cargoHash = "sha256-7bz9iEMvf2o2I0SsnXaZ0135PlMm73DrJ9ZhSqAjcKY=";

  zigDeps = zig_0_16.fetchDeps {
    inherit (finalAttrs) pname version;
    src = "${finalAttrs.src}/vendor/ghostty";
    fetchAll = true;
    hash = "sha256-G9xbZ/pyQTDIfzG0h++i70a45zpwyYpZMBZfAnoOQw0=";
  };

  nativeBuildInputs = [
    rustPlatform.bindgenHook
    pkg-config
    # ghostty-sys runs bindgen with clang's builtin headers when clang is on
    # PATH; otherwise it uses Zig's, where bindgen finds no stdint.h.
    clang
    copyDesktopItems
  ];

  buildInputs = [
    fontconfig
    freetype
    libxcb
    libxkbcommon
    zstd
  ];

  env.ZIG = lib.getExe zig_0_16;

  postPatch = ''
    # Bundled Zig runtimes cause overlapping unwind frames when linked with Rust.
    substituteInPlace vendor/ghostty/src/build/GhosttyLibVt.zig \
      --replace-fail 'lib.bundle_compiler_rt = true;' 'lib.bundle_compiler_rt = false;' \
      --replace-fail 'lib.bundle_ubsan_rt = true;' 'lib.bundle_ubsan_rt = false;'

    substituteInPlace src/links.rs \
      --replace-fail '"xdg-open"' '"${lib.getExe' xdg-utils "xdg-open"}"'
    substituteInPlace vendor/gpui-pre-linux/src/linux/platform.rs \
      --replace-fail 'new_std_command("xdg-open")' 'new_std_command("${lib.getExe' xdg-utils "xdg-open"}")'

    # The app looks for hc on PATH, then in usual install places; add this
    # herdr-core after the system profile.
    substituteInPlace src/core_bin.rs \
      --replace-fail 'PathBuf::from("/run/current-system/sw/bin"),' \
        'PathBuf::from("/run/current-system/sw/bin"), PathBuf::from("${herdr-core}/bin"),'

    # Settings tells source builds to update with git
    # (https://github.com/herdrdev/herdr-app/issues/136).
    substituteInPlace defaults/frame/settings/main.js \
      --replace-fail '"A build from source: it updates with git, not here."' \
        '"Managed by nix: update it there."'

    # The tests use /var/tmp, which the sandbox lacks.
    while IFS= read -r -d "" f; do
      substituteInPlace "$f" --replace-fail /var/tmp "$TMPDIR"
    done < <(grep -rlZ --include='*.rs' /var/tmp src)
  ''
  + lib.optionalString (lib.versionAtLeast finalAttrs.version "0.1.12") ''
    # Only the local test runner gets store paths; generated remote commands must stay portable.
    substituteInPlace src/remote_shell.rs \
      --replace-fail '"/bin/bash"' '"${lib.getExe bash}"' \
      --replace-fail '"/usr/bin/printf"' '"${lib.getExe' coreutils "printf"}"' \
      --replace-fail 'cmd.args(&argv[1..])' \
        'cmd.arg(&argv[1]).arg(argv[2].replace("/bin/sh", "${lib.getExe' bash "sh"}")).args(&argv[3..])' \
      --replace-fail '.env("PATH", "/usr/bin:/bin:/usr/sbin:/sbin")' \
        '.env("PATH", "${
          lib.makeBinPath [
            bash
            coreutils
          ]
        }")'
  ''
  +
    lib.optionalString
      (lib.versionAtLeast finalAttrs.version "0.1.13" && lib.versionOlder finalAttrs.version "0.1.15")
      ''
        substituteInPlace src/core_bin.rs \
          --replace-fail 'Command::new("/bin/test")' 'Command::new("${lib.getExe' coreutils "test"}")'
      '';

  preBuild = ''
    export ZIG_GLOBAL_CACHE_DIR=$(mktemp -d)
    cp -rL ${finalAttrs.zigDeps} "$ZIG_GLOBAL_CACHE_DIR/p"
    chmod -R u+w "$ZIG_GLOBAL_CACHE_DIR/p"
  '';

  nativeCheckInputs = [
    # The update check test fetches from a loopback server with curl.
    curl
    # File-watching fixtures create Git repositories.
    git
    # Some tests run programs in $HOME.
    writableTmpDirAsHomeHook
  ];

  # GPUI records element bounds only with debug assertions. Keep the installed build in release mode.
  checkType = "debug";

  checkFlags = [
    # Races a thread against GPUI's test scheduler and fails now and then.
    "--skip=mods::lifecycle_tests::close_starts_native_work_before_releasing_the_copy"
    # Checks THIRD-PARTY-NOTICES against the vendored sources, which postPatch changes.
    "--skip=third_party_notices_are_current_and_complete"
  ];

  # The render and pixel tests draw real frames on Mesa's software Vulkan
  # driver; test binaries lack the RUNPATH entries added in postFixup.
  preCheck = ''
    export FONTCONFIG_FILE=${makeFontsConf { fontDirectories = [ dejavu_fonts ]; }}
    export VK_DRIVER_FILES=${mesa}/share/vulkan/icd.d/lvp_icd.${stdenv.hostPlatform.parsed.cpu.name}.json
    export LD_LIBRARY_PATH=${lib.makeLibraryPath dlopenLibs}
  '';

  desktopItems = [
    (makeDesktopItem {
      name = "herdr-app";
      desktopName = "Herdr";
      comment = "Terminals and coding agents that keep running";
      exec = "herdr-app";
      icon = "herdr-app";
      terminal = false;
      categories = [ "Development" ];
      startupWMClass = "herdr-app";
    })
  ];

  postInstall = ''
    install -Dm644 LICENSE THIRD-PARTY-NOTICES -t $out/share/licenses/herdr-app
    install -Dm644 assets/icons/herdr-ui-icon-clean.svg \
      $out/share/icons/hicolor/scalable/apps/herdr-app.svg
  '';

  # RUNPATH rather than LD_LIBRARY_PATH, which herdr-core would pass on to every
  # terminal. Fixup drops RUNPATH entries the binary doesn't link, so add them after it.
  postFixup = ''
    patchelf --add-rpath ${lib.makeLibraryPath dlopenLibs} $out/bin/herdr-app
  '';

  nativeInstallCheckInputs = [ versionCheckHook ];
  doInstallCheck = true;

  meta = {
    description = "Desktop app for persistent terminals and coding agents";
    homepage = "https://github.com/herdrdev/herdr-app";
    changelog = "https://github.com/herdrdev/herdr-app/blob/v${finalAttrs.version}/CHANGELOG.md";
    license = with lib.licenses; [
      asl20
      ofl
      mit # libghostty-vt, Symbols Nerd Font
    ];
    mainProgram = "herdr-app";
    platforms = lib.platforms.linux;
  };
})
