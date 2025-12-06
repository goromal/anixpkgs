{ pkgs, config, lib, ...}:
let
  cfg = config.services.mailNode;
in {
  options.services.mailNode = {
    enable = lib.mkEnableOption "enable mail node services";
  };
  config = lib.mkIf cfg.enable {
    # Postfix: receive-only mail server
    services.postfix = {
      enable = true;

      # Accept mail for your domain
      domains = [ "andrewtorgesen.com" ];

      # Deliver to local UNIX mailboxes (e.g., /var/mail/goromail)
      enableLocalRecipient = true;

      # No outbound mail = no relayhost
      relayHost = null;

      # Reduce exposed surface
      openFirewall = true;   # opens port 25
      rootAlias = "goromail";  # route root mail to goromail user
    };

    # Create a user that will receive mail
    users.users.goromail = {
      isSystemUser = true;
      home = "/var/mail/goromail";
      createHome = false;  # mailboxes get created automatically
    };

    # OPTIONAL: pipe incoming mail automatically to a script
    # (Uncomment this block if you want your program to process messages immediately)
    #
    # services.postfix.config = ''
    #   # Transport map: send all mail for goromail@yourdomain.com to a script
    #   transport_maps = hash:/etc/postfix/transport;
    # '';
    #
    # environment.etc."postfix/transport".text = ''
    #   goromail@yourdomain.com  localrunner:
    # '';
    #
    # services.postfix.extraConfig = ''
    #   localrunner_destination_recipient_limit = 1
    #   localrunner_destination_concurrency_limit = 1
    #   mailbox_command = /usr/local/bin/process-email.sh
    # '';

    # Make sure Postfix can write mailboxes
    security.wrappers.postdrop = {
      owner = "root";
      group = "postdrop";
      capabilities = "cap_chown,cap_setgid,cap_setuid=ep";
      source = "${pkgs.postfix}/libexec/postfix/postdrop";
    };
  };
}
