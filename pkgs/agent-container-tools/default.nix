{
  aardvark-dns,
  buildah,
  buildah-unwrapped,
  conmon,
  crun,
  fuse-overlayfs,
  iproute2,
  iptables,
  lib,
  netavark,
  nftables,
  passt,
  podman,
  python3,
  shadow,
  slirp4netns,
  stdenv,
  util-linux,
  util-linuxMinimal,
  writeText,
}:
let
  helperPackages = [
    aardvark-dns
    buildah
    buildah-unwrapped
    conmon
    crun
    fuse-overlayfs
    iproute2
    iptables
    netavark
    nftables
    passt
    podman
    shadow
    slirp4netns
    util-linux
    util-linuxMinimal
    util-linuxMinimal.mount
  ];
  safePath = "/run/wrappers/bin:" + lib.makeBinPath helperPackages;
  containersConf = writeText "agent-containers.conf" ''
    [engine]
    events_logger = "file"
    lock_type = "file"
    runtime = "crun"

    [engine.runtimes]
    crun = ["${crun}/bin/crun"]
  '';
  storageConf = writeText "agent-storage.conf" ''
    [storage]
    driver = "overlay"
    graphroot = "/var/empty/agent-container-guard"
    runroot = "/run/agent-container-guard"

    [storage.options.overlay]
    mount_program = "${fuse-overlayfs}/bin/fuse-overlayfs"
  '';
in
stdenv.mkDerivation {
  pname = "agent-container-tools";
  version = "1.0.0";
  src = ./guard.py;
  dontUnpack = true;
  installPhase = ''
    runHook preInstall

    install -Dm0555 "$src" "$out/libexec/agent-container-guard.py"
    substituteInPlace "$out/libexec/agent-container-guard.py" \
      --replace-fail '@podman@' '${podman}/bin/podman' \
      --replace-fail '@buildah@' '${buildah}/bin/buildah' \
      --replace-fail '@safe_path@' '${safePath}' \
      --replace-fail '@containers_conf@' '${containersConf}' \
      --replace-fail '@storage_conf@' '${storageConf}'

    substitute ${./launcher.c} launcher.c \
      --replace-fail '@python@' '${python3}/bin/python3' \
      --replace-fail '@guard@' "$out/libexec/agent-container-guard.py"
    "$CC" -O2 -Wall -Wextra -Werror launcher.c -o agent-container-launcher
    install -Dm0555 agent-container-launcher "$out/bin/podman"
    install -Dm0555 agent-container-launcher "$out/bin/buildah"

    runHook postInstall
  '';

  passthru = {
    inherit
      buildah
      containersConf
      helperPackages
      podman
      safePath
      storageConf
      ;
    enginePackages = helperPackages ++ [ python3 ];
  };

  meta = {
    description = "Guarded rootless Podman and Buildah entry points for local coding agents";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
  };
}
