{ pkgs }:

pkgs.python3.withPackages (p:
  with p; [
    requests # HTTP library

    # lsp-bridge
    epc
    orjson
    sexpdata
    six
    setuptools
    paramiko
    rapidfuzz
    watchdog
  ])
