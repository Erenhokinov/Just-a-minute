{ config, lib, pkgs, ... }:

{
  # Acer Aspire 7 A715-42G — Ryzen 5 5500U (iGPU) + GTX 1650 Max-Q (Optimus)
  #
  # Before using this, find your real bus IDs on the machine:
  #   lspci | grep -E 'VGA|3D'
  # Then convert e.g. "03:00.0" -> "PCI:3:0:0" (decimal, no leading zeros).

  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.graphics = {
    enable = true;
    enable32Bit = true; # needed for Steam/Proton, some Wine apps
  };

  hardware.nvidia = {
    modesetting.enable = true;
    powerManagement.enable = true;        # helps suspend/resume on Optimus
    powerManagement.finegrained = true;   # actually power down the dGPU when idle
    open = true;                          # open kernel module; 1650 Max-Q supports it
    nvidiaSettings = true;

    package = config.boot.kernelPackages.nvidiaPackages.stable;

    prime = {
      offload = {
        enable = true;
        enableOffloadCmd = true; # gives you `nvidia-offload <cmd>`
      };
      amdgpuBusId = "PCI:5:0:0";  # placeholder
      nvidiaBusId = "PCI:1:0:0";  # placeholder
    };
  };
}
