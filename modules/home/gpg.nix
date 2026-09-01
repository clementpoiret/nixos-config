{
  config,
  lib,
  pkgs,
  ...
}:
let
  forwardedHome = "${config.home.homeDirectory}/.gnupg-forwarded";
  signingKeyFingerprint = "71F084CEA427B23537934233CC6B0EED323A6C13";
  signingKeygrip = "E9D127AC2C91CB7403C7745BBE4054D198A17CAD";
  syncForwardedGpgHome = pkgs.writeShellScript "sync-forwarded-gpg-home" ''
    set -eu
    umask 077

    forwarded_home=${lib.escapeShellArg forwardedHome}
    forwarded_private_keys="$forwarded_home/private-keys-v1.d"
    source_stub=${lib.escapeShellArg "${config.programs.gpg.homedir}/private-keys-v1.d/${signingKeygrip}.key"}
    forwarded_stub="$forwarded_private_keys/${signingKeygrip}.key"

    ${pkgs.coreutils}/bin/install -d -m 0700 "$forwarded_home" "$forwarded_private_keys"

    if [ ! -r "$source_stub" ]; then
      echo "Skipping forwarded GPG setup; smartcard signing stub is missing: $source_stub" >&2
      exit 0
    fi
    if ! ${pkgs.gnugrep}/bin/grep -Fq '(shadowed-private-key' "$source_stub"; then
      echo "Refusing to forward a GPG key file that is not a smartcard stub: $source_stub" >&2
      exit 1
    fi
    for key_file in "$forwarded_private_keys"/*.key; do
      if [ -e "$key_file" ] && [ "$key_file" != "$forwarded_stub" ]; then
        echo "Unexpected private key file in forwarded GPG home: $key_file" >&2
        exit 1
      fi
    done

    public_keyring="$forwarded_home/pubring.gpg"
    temporary_keyring="$(${pkgs.coreutils}/bin/mktemp "$forwarded_home/.pubring.gpg.XXXXXX")"
    trap '${pkgs.coreutils}/bin/rm -f "$temporary_keyring"' EXIT
    ${pkgs.gnupg}/bin/gpg --batch --export ${lib.escapeShellArg signingKeyFingerprint} \
      > "$temporary_keyring"
    if [ ! -s "$temporary_keyring" ]; then
      echo "Failed to export GPG public certificate ${signingKeyFingerprint}" >&2
      exit 1
    fi
    ${pkgs.coreutils}/bin/chmod 0600 "$temporary_keyring"
    ${pkgs.coreutils}/bin/mv -f "$temporary_keyring" "$public_keyring"
    trap - EXIT

    ${pkgs.coreutils}/bin/install -m 0600 "$source_stub" "$forwarded_stub"
  '';
in
{
  programs.gpg = {
    enable = true;
    scdaemonSettings = {
      disable-ccid = true;
    };
    settings = {
      personal-cipher-preferences = "AES256 AES192 AES";
      personal-digest-preferences = "SHA512 SHA384 SHA256";
      personal-compress-preferences = "ZLIB BZIP2 ZIP Uncompressed";
      default-preference-list = "SHA512 SHA384 SHA256 AES256 AES192 AES ZLIB BZIP2 ZIP Uncompressed";
      cert-digest-algo = "SHA512";
      s2k-digest-algo = "SHA512";
      s2k-cipher-algo = "AES256";
      charset = "utf-8";
      fixed-list-mode = true;
      no-comments = true;
      no-emit-version = true;
      keyid-format = "0xlong";
      list-options = "show-uid-validity";
      verify-options = "show-uid-validity";
      with-fingerprint = true;
      require-cross-certification = true;
      no-symkey-cache = true;
      use-agent = true;
      throw-keyids = true;
    };
  };

  services.gpg-agent = {
    enable = true;
    enableExtraSocket = true;
    enableSshSupport = false; # do not hijack SSH
    pinentry.package = pkgs.pinentry-qt; # TTY-friendly alt: pkgs.pinentry-curses
    defaultCacheTtl = 28800;
    maxCacheTtl = 86400;
    extraConfig = ''
      ttyname $GPG_TTY
    '';
  };

  home.file.".gnupg-forwarded/gpg.conf".text = ''
    no-default-keyring
    keyring ${forwardedHome}/pubring.gpg
    use-agent
  '';

  systemd.user.services.sync-forwarded-gpg-home = {
    Unit.Description = "Populate the isolated GPG home used for agent forwarding";
    Service = {
      Type = "oneshot";
      RemainAfterExit = false;
      ExecStart = syncForwardedGpgHome;
    };
    Install.WantedBy = [ "default.target" ];
  };
}
