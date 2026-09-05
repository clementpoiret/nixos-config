{
  hardware = {
    cpuModelId = "00A70F41";
    cpuTarget = "znver4";
    kernel = {
      hzTicks = "300";
      lazyRcu = true;
    };
  };

  home = {
    easyeffects = {
      enable = true;
      framework16Presets = true;
    };

    zk.notebookDir = null;
  };

  network.nameservers = [ ];
}
