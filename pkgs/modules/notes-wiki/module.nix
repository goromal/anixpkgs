{ pkgs, lib, config, ... }:
with import ../../nixos/dependencies.nix { inherit config; };
let
  app = "notes-wiki";
  defaultDomain = "localhost";
  globalCfg = config.machines.base;
  cfg = config.services.${app};
in {
  options.services.${app} = {
    enable = mkEnableOption "enable notes wiki server";
    wikiDir = lib.mkOption {
      type = lib.types.str;
      description =
        "Root directory for notes wiki (default: ~/data/${app}/public_html)";
      default = "${globalCfg.homeDir}/data/${app}/public_html";
    };
    domain = lib.mkOption {
      type = lib.types.str;
      description = "Wiki domain (default: ${defaultDomain})";
      default = defaultDomain;
    };
    php = lib.mkOption {
      type = lib.types.package;
      description =
        "PHP build (default: 7.4 until DokuWiki version gets updated)";
      default = anixpkgs.php74;
    };
    openFirewall = lib.mkOption {
      type = lib.types.bool;
      description =
        "Whether to open the specific firewall port for inter-computer usage";
      default = false;
    };
    insecurePort = lib.mkOption {
      type = lib.types.int;
      description = "Public insecure port";
      default = 80;
    };
  };

  config = lib.mkIf cfg.enable {
    networking.firewall.allowedTCPPorts =
      lib.mkIf cfg.openFirewall [ cfg.insecurePort 443 ];

    services.phpfpm.pools.${app} = {
      user = "andrew";
      group = "dev";
      settings = {
        "listen.owner" = config.services.nginx.user;
        "pm" = "dynamic";
        "pm.max_children" = 32;
        "pm.max_requests" = 500;
        "pm.start_servers" = 2;
        "pm.min_spare_servers" = 2;
        "pm.max_spare_servers" = 5;
        "php_admin_value[error_log]" = "stderr";
        "php_admin_flag[log_errors]" = true;
        "catch_workers_output" = true;
      };
      phpPackage = cfg.php;
      phpEnv."PATH" = lib.makeBinPath [ cfg.php ];
    };

    # Reference: https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/services/web-apps/dokuwiki.nix#L418
    services.nginx = {
      enable = true;
      user = "andrew";
      group = "dev";
      virtualHosts.${cfg.domain} = {
        # addSSL = true;
        # enableACME = true;
        listen = [{
          addr = "0.0.0.0";
          port = cfg.insecurePort;
        }];
        root = cfg.wikiDir;
        locations = {
          "~ /(conf/|bin/|inc/|install.php)" = { extraConfig = "deny all;"; };
          "~ ^/data/" = {
            root = "${cfg.wikiDir}/data";
            extraConfig = "internal;";
          };
          "~ ^/lib.*.(js|css|gif|png|ico|jpg|jpeg)$" = {
            extraConfig = "expires 365d;"; # for caching
          };
          "/" = {
            priority = 1;
            index = "doku.php";
            extraConfig = "try_files $uri $uri/ @dokuwiki;";
          };
          "@dokuwiki" = {
            extraConfig = ''
              # rewrites "doku.php/" out of the URLs if you set the userwrite setting to .htaccess in dokuwiki config page
              rewrite ^/_media/(.*) /lib/exe/fetch.php?media=$1 last;
              rewrite ^/_detail/(.*) /lib/exe/detail.php?media=$1 last;
              rewrite ^/_export/([^/]+)/(.*) /doku.php?do=export_$1&id=$2 last;
              rewrite ^/(.*) /doku.php?id=$1&$args last;
            '';
          };
          "~ \\.php$" = {
            extraConfig = ''
              try_files $uri $uri/ /doku.php;
              include ${config.services.nginx.package}/conf/fastcgi_params;
              include ${pkgs.nginx}/conf/fastcgi.conf;
              fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
              fastcgi_param REDIRECT_STATUS 200;
              fastcgi_pass unix:${config.services.phpfpm.pools.${app}.socket};
            '';
          };
        };
      };
    };
    # security.acme = {
    #   acceptTerms = true;
    #   defaults.email = "andrew.torgesen@gmail.com";
    # };
  };
}
