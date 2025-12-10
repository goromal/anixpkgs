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
        virtual_mailbox_mode = 660;
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
    users.users.andrew.extraGroups = [ "goromail" ];

    systemd.tmpfiles.rules = [
      "z /var/mail/goromail     0770 goromail goromail -"
      "z /var/mail/goromail/cur 0770 goromail goromail -"
      "z /var/mail/goromail/new 0770 goromail goromail -"
      "z /var/mail/goromail/tmp 0770 goromail goromail -"
    ];

    systemd.services.fix-mail-perms = {
      description = "Fix permissions of new Postfix mail files";
      serviceConfig = { Type = "oneshot"; };
      script = ''
        for f in /var/mail/goromail/new/*; do
          [ -e "$f" ] || exit 0
          chmod 660 "$f"
        done
      '';
    };

    systemd.paths.fix-mail-perms = {
      description = "Watch for new mail files for goromail";
      pathConfig = {
        PathChanged = "/var/mail/goromail/new";
        PathModified = "/var/mail/goromail/new";
      };
      wantedBy = [ "multi-user.target" ];
    };
  };
}
