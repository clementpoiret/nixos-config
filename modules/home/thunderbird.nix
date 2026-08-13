{
  config,
  lib,
  pkgs,
  ...
}:
let
  protonBridgeCertificate = ../../certs/cert.pem;
  thunderbirdProfileRoot = "${config.home.homeDirectory}/.thunderbird";
in
{
  programs.thunderbird.enable = true;

  # Bridge serves a self-signed, CA-marked certificate. Installing it through
  # Thunderbird's certificate policy grants CA trust and makes Thunderbird
  # reject it as an end-entity certificate. Pin it to Bridge's two loopback
  # endpoints instead.
  home.activation.protonBridgeCertificateOverrides = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    profile_root=${lib.escapeShellArg thunderbirdProfileRoot}
    profiles_file="$profile_root/profiles.ini"

    if [[ -f "$profiles_file" ]]; then
      fingerprint="$(${pkgs.openssl}/bin/openssl x509 \
        -in ${protonBridgeCertificate} \
        -noout \
        -fingerprint \
        -sha256)"
      fingerprint="''${fingerprint#*=}"

      while IFS= read -r profile_path; do
        if [[ "$profile_path" = /* ]]; then
          profile_directory="$profile_path"
        else
          profile_directory="$profile_root/$profile_path"
        fi

        if [[ ! -d "$profile_directory" ]]; then
          continue
        fi

        overrides_file="$profile_directory/cert_override.txt"
        temporary_file="$(${pkgs.coreutils}/bin/mktemp "$profile_directory/.cert_override.txt.XXXXXX")"

        if [[ -f "$overrides_file" ]]; then
          input_file="$overrides_file"
        else
          ${pkgs.coreutils}/bin/printf '%s\n%s\n' \
            '# PSM Certificate Override Settings file' \
            '# This is a generated file! Do not edit.' \
            > "$temporary_file"
          input_file=/dev/null
        fi

        ${pkgs.gawk}/bin/awk -v fingerprint="$fingerprint" '
          BEGIN {
            algorithm = "OID.2.16.840.1.101.3.4.2.1"
            imap = "127.0.0.1:1143:\t" algorithm "\t" fingerprint "\t"
            smtp = "127.0.0.1:1025:\t" algorithm "\t" fingerprint "\t"
          }

          /^127[.]0[.]0[.]1:1143:/ {
            if (!seen_imap) {
              print imap
              seen_imap = 1
            }
            next
          }

          /^127[.]0[.]0[.]1:1025:/ {
            if (!seen_smtp) {
              print smtp
              seen_smtp = 1
            }
            next
          }

          { print }

          END {
            if (!seen_imap) print imap
            if (!seen_smtp) print smtp
          }
        ' "$input_file" >> "$temporary_file"

        if ${pkgs.diffutils}/bin/cmp --silent "$temporary_file" "$overrides_file"; then
          ${pkgs.coreutils}/bin/rm "$temporary_file"
        else
          ${pkgs.coreutils}/bin/mv "$temporary_file" "$overrides_file"
        fi
      done < <(
        ${pkgs.gawk}/bin/awk '
          /^Path=/ {
            path = substr($0, 6)
            sub(/\r$/, "", path)
            print path
          }
        ' "$profiles_file"
      )
    fi
  '';
}
