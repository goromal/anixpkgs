{ pkgs, lib, config, ... }:
with pkgs;
with lib;
with import ../../nixos/dependencies.nix { inherit config; };
let
  app = "notes-wiki";
  globalCfg = config.machines.base;
  cfg = config.services.${app};
in {
  options.services.${app} = {
    wikiDir = lib.mkOption {
      type = lib.types.str;
      description =
        "Root directory for notes wiki (default: ~/data/${app}/public_html)";
      default = "${globalCfg.homeDir}/data/${app}/public_html";
    };
    domain = lib.mkOption {
      type = lib.types.str;
      description = "Wiki domain (default: notes.andrewtorgesen.com)";
      default = "notes.andrewtorgesen.com";
    };
    php = lib.mkOption {
      type = lib.types.package;
      description = "PHP build (default: 7.4 until DokuWiki version gets updated)";
      default = anixpkgs.php74;
    };
  };

  config = {
    services.phpfpm.pools.${app} = {
      user = app;
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
    services.nginx = {
      enable = true;
      virtualHosts.${cfg.domain}.locations."/" = {
        root = cfg.wikiDir;
        extraConfig = ''
          fastcgi_split_path_info ^(.+\.php)(/.+)$;
          fastcgi_pass unix:${config.services.phpfpm.pools.${app}.socket};
          include ${pkgs.nginx}/conf/fastcgi.conf;
        '';
      };
    };
    users.users.${app} = {
      isSystemUser = true;
      createHome = true;
      home = cfg.wikiDir;
      group = app;
    };
    users.groups.${app} = { };
  };
}
