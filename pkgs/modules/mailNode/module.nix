{ pkgs, config, lib, ... }:
let cfg = config.services.mailNode;
in {
  options.services.mailNode = {
    enable = lib.mkEnableOption "enable mail node services";
  };
  config = lib.mkIf cfg.enable {
    services.postfix = {
      enable = true;
      hostname = "mail.andrewtorgesen.com";
      domain = "andrewtorgesen.com";
      mapFiles = {
        # virtual_mailbox_maps = ./virtual_mailbox_maps;
        transport = ./virtual_transport;
      };
      config = {
        virtual_mailbox_base = "/var/mail/goromail/";
        # virtual_mailbox_maps = "hash:/etc/postfix/virtual_mailbox_maps";
        virtual_transport_maps = "hash:/etc/postfix/transport";
        virtual_mailbox_domains = "andrewtorgesen.com";
        virtual_uid_maps = "static:994";
        virtual_gid_maps = "static:993";
      };
      extraMasterConf = ''
        gorogatherer  unix  -  n  n  -  -  pipe
          flags=Rq user=goromail argv=/usr/local/bin/gorogather -- ''${recipient}
      '';
    };

    environment.systemPackages = [
      (pkgs.writeShellScriptBin "gorogather" ''
        echo - > /data/andrew/TMPMAIL
      '')
    ];

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
  };
}
