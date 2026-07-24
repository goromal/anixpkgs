# Essential system configuration shared between the installer ISOs (flake.nix) and
# full system profiles (pc-base.nix). This module is intentionally minimal and
# free of the heavier profile machinery (home-manager, services, overlays, etc.)
# so that it can be imported directly inside bare installer closures.
{ ... }:
let
  homeDir = "/data/andrew";
in
{
  # Primary user and group -------------------------------------------------------

  users.groups.dev = {
    gid = 1000;
  };

  users.users.andrew = {
    isNormalUser = true;
    uid = 1000;
    home = homeDir;
    createHome = true;
    description = "Andrew Torgesen";
    group = "dev";
    extraGroups = [
      "users"
      "wheel"
      "networkmanager"
      "dialout"
      "video"
      "input"
      "docker"
      "systemd-journal"
      "wireshark"
    ];
    subUidRanges = [
      {
        count = 1;
        startUid = 1000;
      }
      {
        count = 65536;
        startUid = 100000;
      }
    ];
    subGidRanges = [
      {
        count = 1;
        startGid = 100;
      }
      {
        count = 65536;
        startGid = 100000;
      }
    ];
    hashedPassword = "$6$0fv.6VfJi8qfOLtZ$nJ9OeiLzDenXaogPJl1bIe6ipx4KTnsyPExB.9sZk/dEXfFv34PtRRxZf28RKwrpcg5bgmee6QiQFGQQhv4rS/";
    openssh.authorizedKeys.keys = [
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDCoLIZom32sRQevjei3ZhHnJIDDNdvNqB191cIuiiv1pxGGYzBU5VdIx8SETON2ZRrVYKuPpFtaIAD+H1ZjJtzqVqaicnJht3zZUEu+uRbeNFQGdtSlAjZ+Yww6OA2eQ/8LQkXvIKskpUq78UY1lSEsyRt5bZccEAUW0gp3uT7d3S0gjy4hOauSkdSh5Ff2q1thB9qI22ngEfNlj/y0kBLZWPzkdKpp9xuqDPGojdLk4Gbs6uxsJJdwsRecR405F9obICxOPLBYH9LVPUn/XxL6KJkFi/kPAjLYnFY51Ie0aVRm26fAF0yGB8gw6zMzfU6VXXq5Lye++WjOiecd8AHk0na06/Cns5sdAPk+RDz0Wf9rRKBm4k6pgw6emrHGPMbDwZkbpTC2YJnma8Wm70LRNZSElASFSD/AdpKqpdJoi1Yfi82+AASMtaTPr96zoQ3RO/X3js86urGavLKbGaI/f2hOk2+f+jHP4jGzmnqZ4KPDcWl2Sx5yx+rPI/wGKM= andrew@nixos"
    ];
  };

  users.mutableUsers = true;

  # /data filesystem entry so andrew's home dir can be created -------------------

  systemd.tmpfiles.rules = [
    "d /data 0777 root root"
    "d ${homeDir}/sources 0755 andrew dev -"
  ];

  # Nix daemon settings ----------------------------------------------------------

  nix.settings = {
    auto-optimise-store = true;
    max-jobs = 4;
    cores = 4;
    substituters = [
      "https://cache.nixos.org/"
      "https://github-public.cachix.org"
    ];
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "github-public.cachix.org-1:xofQDaQZRkCqt+4FMyXS5D6RNenGcWwnpAXRXJ2Y5kc="
    ];
  };

  nix.extraOptions = ''
    narinfo-cache-positive-ttl = 0
    narinfo-cache-negative-ttl = 0
    experimental-features = nix-command flakes
  '';

  # Networking -------------------------------------------------------------------

  networking.useDHCP = false;
  networking.networkmanager.enable = true;

  # SSH --------------------------------------------------------------------------

  services.openssh = {
    enable = true;
    settings = {
      X11Forwarding = true;
    };
  };

  # Locale -----------------------------------------------------------------------

  time.timeZone = "America/Los_Angeles";
  i18n.defaultLocale = "en_US.UTF-8";
  console = {
    font = "Lat2-Terminus16";
    keyMap = "us";
  };
}
