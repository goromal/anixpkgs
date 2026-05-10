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
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDARsquoLlZN+DIsqoBh1tQ4h5E+V1UD7SpBZCpzcWMHY+N8SJ6CnYKUiQU8FSCWSOhdZ1r52za+iMl0g983S71cH70attk5KvQYHYGfqpSckwIQ326wE6e+fPQAytgqv6CS+xjNzcpRwVRzBmlB1IyqNCl79OnWsg0TXxL/GBt3UUI9p6XjAeZhxpqb2NPZYHV+TZPPvI3/1X0LadBZZWFPbtoI+XbHABtW06YUDpR+BQSpFGtq+2eIjRgoo4WEHPewV73zzLVIYZ3xaa0Whmm4qTPpNtw+U1tHZkxUAjU92Y7Mq7oehd5z6YGRQ+UxSAuSYkR7xTt63KFb/vTjJg0W0LphwPYnfzG1M+jhK/6rGAdL0AYaUiMDTwl6gSkROKAzab63wf9gbeo+6Smgv3LQYCXvAFccEKtqlt1RLP/SUdTCdjVL728c0+WohrOD3tyRR8XU94CdOyLrhRG0k4Bcb0W0GYaLxsUSkc/wSyg6An9ITldBfH0FOON2sft52M= andrew@andrew-Precision-5550"
    ];
  };

  users.mutableUsers = true;

  # /data filesystem entry so andrew's home dir can be created -------------------

  systemd.tmpfiles.rules = [
    "d /data 0777 root root"
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
