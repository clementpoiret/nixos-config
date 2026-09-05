{
  hardware = {
    cpuModelId = "00B40F40";
    cpuTarget = "znver5";
    kernel = {
      hzTicks = "500";
      lazyRcu = false;
    };
  };

  home = {
    easyeffects = {
      enable = false;
      framework16Presets = false;
    };

    zk.notebookDir = null;
  };

  network.nameservers = [ ];
}
