{
  lib,
  pkgs,
  ...
}:
let
  rocmLibPath = lib.makeLibraryPath [ pkgs.libdrm ];

  rocmSmi = pkgs.writeShellScriptBin "rocm-smi" ''
    export LD_LIBRARY_PATH="${rocmLibPath}''${LD_LIBRARY_PATH:+:}''${LD_LIBRARY_PATH:-}"
    exec ${pkgs.rocmPackages.rocm-smi}/bin/rocm-smi "$@"
  '';

  rocmEnv = pkgs.symlinkJoin {
    name = "rocm-combined";
    paths = with pkgs.rocmPackages; [
      rocblas
      hipblas
      clr
    ];
  };
in
{
  environment.systemPackages = with pkgs; [
    amdgpu_top
    clinfo
    rocmPackages.rocminfo
    rocmSmi
  ];

  hardware.amdgpu = {
    initrd.enable = true;
    opencl.enable = true;
  };

  services.xserver.videoDrivers = [ "modesetting" ];

  systemd.tmpfiles.rules = [
    "L+    /opt/rocm   -    -    -     -    ${rocmEnv}"
  ];
}
