{
  lib,
  stdenvNoCC,
  ostree,
  cacert,
  runCommand,
  writeShellScript,
  writeTextDir,
  bubblewrap,
}:
let
  version = "26.04.3.3-1";

  # Fetch immutable Flathub commits, then retain only their installed files.
  # Neither Flatpak nor OSTree is needed when running the application.
  fetchFiles =
    name: commit: hash:
    stdenvNoCC.mkDerivation {
      inherit name;
      nativeBuildInputs = [ ostree ];
      SSL_CERT_FILE = "${cacert}/etc/ssl/certs/ca-bundle.crt";
      outputHashMode = "recursive";
      outputHashAlgo = "sha256";
      outputHash = hash;
      dontUnpack = true;
      dontFixup = true;
      buildCommand = ''
        ostree --repo=repo init --mode=archive
        # Nix verifies the entire checkout against outputHash.
        ostree --repo=repo remote add --no-gpg-verify \
          --set=tls-ca-path=$SSL_CERT_FILE flathub https://dl.flathub.org/repo
        ostree --repo=repo pull --depth=0 --disable-static-deltas \
          --http-header='User-Agent=curl/8.18.0' flathub ${commit}
        ostree --repo=repo checkout --user-mode --subpath=/files ${commit} "$out"
      '';
    };

  app =
    fetchFiles "collabora-desktop-bin-files-${version}"
      "ea63f13fca944be938b64e5c3e9212c02c10f1eb163c4f30191130cba419f106"
      "sha256-alHz0DXhG+q2UbGP6xUm1rcyEGsfNW/tOT8vpIFxx4c=";
  runtime =
    fetchFiles "collabora-kde-runtime-6.10"
      "31742ff0f905913c512ea732960bbdeffa8306dcbebca45eeee62bfed0ca03a3"
      "sha256-BudziP+BfIklxpnOHTGd0I0ppKSz2F4fW/QRNpoGTMY=";
  graphics =
    fetchFiles "collabora-mesa-runtime-25.08"
      "0083f33e9a33c454d0f0850d06581e5f991ecf2dbde02e38079db49e01c7ebac"
      "sha256-p2uV/VOqwA+8uKS+HLe5IKQ67FNJsfcJmL811/jV6v8=";

  runtimeRoot = runCommand "collabora-runtime-root" { } ''
    mkdir -p "$out"
    cp -rs ${runtime}/. "$out/"
    chmod u+w "$out/lib/x86_64-linux-gnu/GL"
    mkdir -p "$out/lib/x86_64-linux-gnu/GL/default"
    cp -rs ${graphics}/. "$out/lib/x86_64-linux-gnu/GL/default/"
    ln -s default/lib "$out/lib/x86_64-linux-gnu/GL/lib"
  '';

  hostFonts = writeTextDir "font-dirs.xml" ''
    <?xml version="1.0"?>
    <!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">
    <fontconfig>
      <dir>/usr/share/fonts</dir>
      <dir>/app/collaboraoffice/share/fonts/truetype</dir>
      <dir prefix="xdg">fonts</dir>
      <dir>~/.fonts</dir>
    </fontconfig>
  '';

  launcher = writeShellScript "collabora-desktop-bin" ''
    set -euo pipefail
    shopt -s nullglob
    mounts=()
    # Preserve host paths for documents and desktop sockets. Give /run its
    # own parent so /run/host can be provided without modifying the host.
    for path in /* /run/*; do
      case "$path" in
        /app|/usr|/lib|/lib64|/bin|/sbin|/dev|/proc|/sys|/run|/run/host) ;;
        *) mounts+=(--bind "$path" "$path") ;;
      esac
    done
    exec ${bubblewrap}/bin/bwrap \
      "''${mounts[@]}" \
      --ro-bind ${runtimeRoot} /usr \
      --ro-bind ${app} /app \
      --ro-bind ${hostFonts} /run/host \
      --symlink usr/lib /lib \
      --symlink usr/lib64 /lib64 \
      --symlink usr/bin /bin \
      --symlink usr/sbin /sbin \
      --dev-bind /dev /dev \
      --proc /proc \
      --ro-bind /sys /sys \
      --setenv PATH /app/bin:/usr/bin \
      --setenv LD_LIBRARY_PATH /app/lib:/app/lib/x86_64-linux-gnu:/usr/lib:/usr/lib/x86_64-linux-gnu:/usr/lib/x86_64-linux-gnu/GL/default/lib \
      --setenv QT_PLUGIN_PATH /app/lib/plugins:/usr/lib/plugins \
      --setenv QML2_IMPORT_PATH /app/lib/qml:/usr/lib/qml \
      --setenv XDG_DATA_DIRS /app/share:/usr/share:/usr/share/runtime/share:"''${XDG_DATA_DIRS:-/run/current-system/sw/share}" \
      --setenv FONTCONFIG_FILE /usr/etc/fonts/fonts.conf \
      --setenv FONTCONFIG_PATH /usr/etc/fonts \
      --setenv OPENSSL_CONF /usr/etc/pki/tls/openssl.cnf \
      --setenv LIBGL_DRIVERS_PATH /usr/lib/x86_64-linux-gnu/GL/default/lib/dri \
      --setenv __EGL_VENDOR_LIBRARY_FILENAMES /usr/lib/x86_64-linux-gnu/GL/default/glvnd/egl_vendor.d/50_mesa.json \
      -- /app/bin/coda-qt "$@"
  '';
in
runCommand "collabora-desktop-bin-${version}"
  {
    inherit version;
    pname = "collabora-desktop-bin";
    passthru = {
      inherit
        app
        runtime
        graphics
        runtimeRoot
        ;
    };
    meta = {
      description = "Collabora Office desktop, repackaged from Flathub binaries";
      homepage = "https://www.collaboraonline.com/collabora-office/";
      license = lib.licenses.mpl20;
      platforms = [ "x86_64-linux" ];
      mainProgram = "collabora-desktop-bin";
    };
  }
  ''
    mkdir -p "$out/bin" "$out/share/applications"
    ln -s ${launcher} "$out/bin/collabora-desktop-bin"
    ln -s collabora-desktop-bin "$out/bin/coda-qt"
    cp ${app}/share/applications/*.desktop "$out/share/applications/"
    substituteInPlace "$out"/share/applications/*.desktop \
      --replace-fail 'Exec=coda-qt' "Exec=$out/bin/collabora-desktop-bin"
    ln -s ${app}/share/icons "$out/share/icons"
    ln -s ${app}/share/metainfo "$out/share/metainfo"
  ''
