{pkgs, ...}: {
  home.packages = with pkgs; [
    macmon # Apple Silicon CPU/GPU/ANE/power monitor (btm can't see the GPU).
  ];
}
