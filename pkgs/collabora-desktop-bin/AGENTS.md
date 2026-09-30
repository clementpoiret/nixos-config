# Collabora binary package

- Keep the Flathub app, KDE runtime, and Mesa extension compatible when updating pins. Hashes cover each commit's `/files` checkout with `ostree checkout --user-mode --subpath=/files`.
- OSTree needs its remote's `tls-ca-path` set explicitly inside the Nix builder; `SSL_CERT_FILE` alone did not configure its HTTPS certificate verification.
- For launch verification while Collabora is already running, use a separate `dbus-run-session` and a temporary document. Collabora forwards to an existing instance even with separate XDG configuration directories. `--writer` creates a real document in the user's Documents directory.
- Verify document rendering on Wayland. The upstream QtWebEngine app crashed with the `offscreen` Qt platform during testing; `--version` alone does not exercise the office engine.
