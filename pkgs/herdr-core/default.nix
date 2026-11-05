# Adapted from nixpkgs PR #581031; replace with upstream's package once herdr ships a flake.
{
  lib,
  rustPlatform,
  fetchFromGitHub,
  zig_0_16,
  installAgentSkills,
  bash,
  coreutils,
  curl,
  gawk,
  git,
  jq,
  gnused,
  gnutar,
  gzip,
  libarchive,
  python3,
  strace,
  versionCheckHook,
}:
rustPlatform.buildRustPackage (finalAttrs: {
  pname = "herdr-core";
  version = "0.1.16";

  __structuredAttrs = true;

  src = fetchFromGitHub {
    owner = "herdrdev";
    repo = "herdr-core";
    tag = "v${finalAttrs.version}";
    fetchSubmodules = true;
    hash = "sha256-TIOXZswCum0g3qcDK+RDZb9Y7lUu+bx+Oyja4EtKKh4=";
  };

  cargoHash = "sha256-hMkych62liZ+Oe5huM2drN5/6ckpF8AEHH2dyskcivo=";

  zigDeps = zig_0_16.fetchDeps {
    inherit (finalAttrs) pname version;
    src = "${finalAttrs.src}/vendor/ghostty";
    fetchAll = true;
    hash = "sha256-G9xbZ/pyQTDIfzG0h++i70a45zpwyYpZMBZfAnoOQw0=";
  };

  nativeBuildInputs = [ installAgentSkills ];

  patches = [ ./restart-lock-lifetime.patch ];

  env = {
    ZIG = lib.getExe zig_0_16;
    # hc tells builds apart by their GNU build id, so a byte-identical copy of
    # the binary counts as the same build.
    NIX_SET_BUILD_ID = "1";
    # The build id hashes debug sections holding per-build Zig cache paths;
    # dropping them at link time keeps it reproducible.
    NIX_LDFLAGS = "--strip-debug";
  };

  postPatch =
    let
      # What the tests expect on the other machine.
      remoteBin = lib.makeBinPath [
        bash
        coreutils
        gawk
        python3
      ];
      # What install.sh calls.
      installerBin = lib.makeBinPath [
        bash
        coreutils
        curl
        gnused
        gnutar
        gzip
      ];
    in
    ''
      # Bundled Zig runtimes cause overlapping unwind frames when linked with Rust.
      substituteInPlace vendor/ghostty/src/build/GhosttyLibVt.zig \
        --replace-fail 'lib.bundle_compiler_rt = true;' 'lib.bundle_compiler_rt = false;' \
        --replace-fail 'lib.bundle_ubsan_rt = true;' 'lib.bundle_ubsan_rt = false;'

      # hc downloads, checks and unpacks release builds for machines it adds.
      # bsdtar unpacks gzip itself; ssh and the systemd tools stay on PATH
      # because they have to match the host.
      substituteInPlace crates/herdr-core/src/releases.rs \
        --replace-fail 'Command::new("curl")' 'Command::new("${lib.getExe curl}")' \
        --replace-fail 'run("sha256sum"' 'run("${lib.getExe' coreutils "sha256sum"}"' \
        --replace-fail '_ => "tar".into()' '_ => "${lib.getExe' libarchive "bsdtar"}".into()'

      # hc copies its own binary to machines with the same OS and CPU, but this
      # one depends on /nix/store paths those machines may lack. Use the
      # statically linked release build for every machine instead.
      substituteInPlace crates/herdr-core/src/machines.rs \
        --replace-fail 'if there == here' 'if false'

      # The tests use /var/tmp, which the sandbox lacks.
      while IFS= read -r -d "" f; do
        substituteInPlace "$f" --replace-fail /var/tmp "$TMPDIR"
      done < <(grep -rlZ --include='*.rs' /var/tmp crates/herdr-core)

      # The tests' fake ssh and installer runs use PATH=/usr/bin:/bin, which the sandbox lacks.
      substituteInPlace crates/herdr-core/tests/common/mod.rs \
        --replace-fail ':/usr/bin:/bin ' ':${remoteBin} ' \
        --replace-fail 'PATH=/usr/bin:/bin ' 'PATH=${remoteBin} '
      substituteInPlace crates/herdr-core/tests/distribution.rs \
        --replace-fail '.env("PATH", "/usr/bin:/bin")' '.env("PATH", "${installerBin}")' \
        --replace-fail '"{}:/usr/bin:/bin"' '"{}:${installerBin}"'

      # tests/distribution.rs runs this python3 script.
      patchShebangs scripts/manifest
    '';

  preBuild = ''
    export ZIG_GLOBAL_CACHE_DIR=$(mktemp -d)
    cp -rL ${finalAttrs.zigDeps} "$ZIG_GLOBAL_CACHE_DIR/p"
    chmod -R u+w "$ZIG_GLOBAL_CACHE_DIR/p"
  '';

  nativeCheckInputs = [
    # Installer and mocked signing fixtures also use the inherited check PATH.
    curl
    git
    jq
    python3
  ];

  # postPatch makes hc download a release build for every machine it sets up,
  # and these tests set one up without network access.
  checkFlags = [
    "--skip=a_box_without_hc_gets_this_one_when_you_say_yes"
    "--skip=a_machine_reached_through_any_command_works_like_one_over_ssh"
  ];

  # Upstream CI's settings for slow runners.
  preCheck = ''
    export HC_TEST_WATCHDOG_S=120
    export HC_TEST_SLOW_RUNNER=1
  '';

  # The hook would also install src/SKILL.md (compiled into `hc --skill`) and
  # Ghostty's skill; only the stub under skills/ is meant to be installed.
  dontInstallAgentSkills = true;

  postInstall = ''
    ln -s herdr-core $out/bin/hc
    installSkill skills/herdr-core
    install -Dm644 LICENSE crates/herdr-core/THIRD-PARTY-NOTICES -t $out/share/licenses/herdr-core
  '';

  nativeInstallCheckInputs = [
    python3
    strace
    versionCheckHook
  ];
  doInstallCheck = true;

  postInstallCheck = ''
    python3 ${./test-restart.py} "$out/bin/hc"
  '';

  meta = {
    description = "Persistent terminal and coding agent backend for Herdr";
    homepage = "https://github.com/herdrdev/herdr-core";
    license = with lib.licenses; [
      asl20
      mit # libghostty-vt
    ];
    mainProgram = "hc";
    platforms = lib.platforms.linux;
  };
})
