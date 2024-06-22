{ pkgs, lib, config, ... }:
with pkgs;
with lib;
with import ../../nixos/dependencies.nix { inherit config; };
let
  app = "notes-wiki";
  defaultDomain = "public_html";
  globalCfg = config.machines.base;
  cfg = config.services.${app};
in {
  options.services.${app} = {
    enable = mkEnableOption "enable notes wiki server";
    wikiDir = lib.mkOption {
      type = lib.types.str;
      description =
        "Root directory for notes wiki (default: ~/data/${app}/${defaultDomain})";
      default = "${globalCfg.homeDir}/data/${app}/${defaultDomain}";
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
  };

  config = mkIf cfg.enable {
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
      phpEnv."PATH" = lib.makeBinPath [ cfg.php ];
    };
    services.nginx =
      { # TODO https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/services/web-apps/dokuwiki.nix#L418
        enable = true;
        virtualHosts.${cfg.domain}.locations."/" = {
          index = "doku.php";
          root = cfg.wikiDir;
          extraConfig = ''
            fastcgi_split_path_info ^(.+\.php)(/.+)$;
            fastcgi_pass unix:${config.services.phpfpm.pools.${app}.socket};
            include ${pkgs.nginx}/conf/fastcgi.conf;
          '';
        };
      };
  };
}
