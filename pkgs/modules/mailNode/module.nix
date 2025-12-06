{ pkgs, config, lib, ... }:
let
  globalCfg = config.machines.base;
  cfg = config.services.mailNode;
in {
  options.services.mailNode = {
    enable = lib.mkEnableOption "enable mail node services";
  };
  config = lib.mkIf cfg.enable {
    services.postfix = {
      enable = true;
      hostname = "mail.andrewtorgesen.com";
      domain = "andrewtorgesen.com";
      config = {
        virtual_mailbox_base = "/var/mail/goromail/";
        virtual_mailbox_domains = "andrewtorgesen.com";
        virtual_uid_maps = "static:994";
        virtual_gid_maps = "static:993";
      };
    };

    # Open the firewall
    # NOTE: requires router port-forwarding as well
    #       test with `nc -zv <public_ip> 25`
    networking.firewall.allowedTCPPorts = [ 25 ];

    users.users.goromail = {
      isSystemUser = true;
      home = "/var/mail/goromail";
      createHome = false;
      uid = 994;
      group = "goromail";
    };
    users.groups.goromail = { gid = 993; };

    systemd.tmpfiles.rules =
      [ "d ${globalCfg.homeDir}/mail 0770 andrew dev -" ];
    users.users.goromail.extraGroups = [ "dev" ];
    fileSystems."/var/mail/goromail" = {
      device = "${globalCfg.homeDir}/mail";
      fsType = "none";
      options = [ "bind" ];
    };
  };
}
