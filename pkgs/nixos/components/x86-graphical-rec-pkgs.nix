{ pkgs, config, lib, ... }:
with import ../dependencies.nix { inherit config; }; {
  home.packages = [
    pavucontrol # compatible with pipewire-pulse
    anixpkgs.trafficsim
    anixpkgs.la-quiz
    anixpkgs.budget_report
  ];

}
