{ pkgs, config, lib, ... }:
let cfg = config.services.mailNode;
in {
  options.services.mailNode = {
    enable = lib.mkEnableOption "enable mail node services";
  };
  config = lib.mkIf cfg.enable {
    # Postfix: receive-only mail server
    services.postfix = {
      enable = true;
      hostname = "mail.andrewtorgesen.com";
      domain = "andrewtorgesen.com";
      # mapFiles = {
      #   virtual_mailbox_maps = ./virtual_mailbox_maps;
      # };
      config = {
        virtual_mailbox_base = "/var/mail/goromail/";
        # virtual_mailbox_maps = "hash:/etc/postfix/virtual_mailbox_maps";
        virtual_mailbox_domains = "andrewtorgesen.com";
        virtual_uid_maps = "static:994";
        virtual_gid_maps = "static:993";
      };
    };

    # Open the firewall
    networking.firewall.allowedTCPPorts = [ 25 ];

    # Create a user that will receive mail
    users.users.goromail = {
      isSystemUser = true;
      home = "/var/mail/goromail";
      createHome = false; # mailboxes get created automatically
      uid = 994;
      group = "goromail";
    };
    users.groups.goromail = { gid = 993; };

    # # Make sure Postfix can write mailboxes
    # security.wrappers.postdrop = {
    #   owner = "root";
    #   group = "postdrop";
    #   capabilities = "cap_chown,cap_setgid,cap_setuid=ep";
    #   source = "${pkgs.postfix}/libexec/postfix/postdrop";
    # };
  };
}
