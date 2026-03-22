{
  pkgs,
  lib,
  config,
  ...
}:
with import ../../nixos/dependencies.nix;
let
  globalCfg = config.machines.base;
  cfg = config.services.notes-wiki;
in
{
  options.services.notes-wiki = {
    enable = lib.mkEnableOption "enable notes wiki server";
    dataWikiDirname = lib.mkOption {
      type = lib.types.str;
      description = "Subdirectory name in the data dir where the wiki resides";
      default = "notes-wiki";
    };
    wikiDir = lib.mkOption {
      type = lib.types.str;
      description = "Root directory for notes wiki (default: ~/data/${cfg.dataWikiDirname}/public_html)";
      default = "${globalCfg.homeDir}/data/${cfg.dataWikiDirname}/public_html";
    };
    php = lib.mkOption {
      type = lib.types.package;
      description = "PHP build (default: 7.4 until DokuWiki version gets updated)";
      default = anixpkgs.php74;
    };
  };

  config = lib.mkIf cfg.enable {
    services.phpfpm.pools.notes-wiki = {
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

    machines.base.runWebServer = true;
    # Reference: https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/services/web-apps/dokuwiki.nix#L418
    services.nginx.virtualHosts."${config.networking.hostName}.local" = {
      root = cfg.wikiDir;
      locations = {
        "~ ^/wiki/(conf/|bin/|inc/|install.php)" = {
          extraConfig = "deny all;";
        };
        "~ ^/wiki/data/" = {
          root = "${cfg.wikiDir}/data";
          extraConfig = "internal;";
        };
        "~ ^/wiki/lib.*.(js|css|gif|png|ico|jpg|jpeg)$" = {
          extraConfig = "expires 365d;"; # for caching
        };
        "/wiki/" = {
          priority = 1;
          index = "doku.php";
          extraConfig = "try_files $uri $uri/ @dokuwiki;";
        };
        "@dokuwiki" = {
          extraConfig = ''
            # Rewrites to handle URLs under /wiki/
            rewrite ^/wiki/_media/(.*) /lib/exe/fetch.php?media=$1 last;
            rewrite ^/wiki/_detail/(.*) /lib/exe/detail.php?media=$1 last;
            rewrite ^/wiki/_export/([^/]+)/(.*) /doku.php?do=export_$1&id=$2 last;
            rewrite ^/wiki/(.*) /doku.php?id=$1&$args last;
          '';
        };
        "~ \\.php$" = {
          extraConfig = ''
            try_files $uri $uri/ /doku.php;
            include ${config.services.nginx.package}/conf/fastcgi_params;
            include ${pkgs.nginx}/conf/fastcgi.conf;
            fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
            fastcgi_param REDIRECT_STATUS 200;
            fastcgi_pass unix:${config.services.phpfpm.pools.notes-wiki.socket};
          '';
        };
      };
    };
  };
}
