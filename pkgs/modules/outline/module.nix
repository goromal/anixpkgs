{
  pkgs,
  lib,
  config,
  ...
}:
with import ../../nixos/dependencies.nix;
let
  cfg = config.services.outlineNode;
  dexPort = service-ports.dex;
  outlinePort = service-ports.outline;
  dexIssuer = "http://127.0.0.1:${builtins.toString dexPort}";
  dexClientId = "outline";
  # Secrets live in /var/lib/outline (the outline service's StateDirectory).
  # Since the service runs as andrew, systemd creates this dir owned by andrew.
  outlineStateDir = "/var/lib/outline";
  dexClientSecretFile = "${outlineStateDir}/dex-client-secret";
  outlineSecretKeyFile = "${outlineStateDir}/secret-key";
  outlineUtilsSecretFile = "${outlineStateDir}/utils-secret";
in
{
  options.services.outlineNode = {
    enable = lib.mkEnableOption "enable Outline wiki server";
    rootDir = lib.mkOption {
      type = lib.types.str;
      description = "Directory where the outlineDocs symlink and defaultOutlineDocs live";
      default = "/data/andrew/outline";
    };
    defaultMarkdownDirname = lib.mkOption {
      type = lib.types.str;
      description = "Name of the default docs directory within rootDir";
      default = "defaultOutlineDocs";
    };
  };

  config = lib.mkIf cfg.enable {
    # Run outline as andrew so it can access any directory andrew owns
    # without needing manual permission changes. The NixOS outline module sets
    # the redis-outline service Group to the user name, so we need a group
    # named "andrew" to exist.
    users.groups.andrew = { };
    services.outline.user = "andrew";

    systemd.tmpfiles.rules = [
      "d ${cfg.rootDir}                                       - andrew dev"
      "d ${cfg.rootDir}/${cfg.defaultMarkdownDirname}         - andrew dev"
    ];

    # Setup service: manages the docs symlink and persistent secret files.
    # Runs before outline.service on every start/restart; does NOT run on
    # boot independently (so the symlink persists across reboots).
    systemd.services.outline-setup = {
      description = "Prepare Outline runtime state (symlink + secrets)";
      before = [
        "outline.service"
        "dex.service"
      ];
      after = [ "systemd-tmpfiles-setup.service" ];
      partOf = [ "outline.service" ];
      wantedBy = [ "outline.service" ];
      unitConfig.StartLimitIntervalSec = 0;
      serviceConfig = {
        Type = "oneshot";
        User = "andrew";
      };
      script = ''
        set -euo pipefail

        # Ensure the state dir exists; systemd creates it when outline.service
        # activates, but outline-setup runs before that.
        install -d -m 750 ${outlineStateDir}

        # Create the docs symlink on first run only; subsequent restarts leave
        # it alone so manual re-pointing persists across restarts/reboots.
        # If a plain directory exists at the link path (from a failed earlier
        # run), replace it with the symlink.
        link="${cfg.rootDir}/outlineDocs"
        if [ -d "$link" ] && [ ! -L "$link" ]; then
          ${pkgs.coreutils}/bin/rm -rf "$link"
        fi
        if [ ! -e "$link" ]; then
          ${pkgs.coreutils}/bin/ln -sfn \
            ${cfg.rootDir}/${cfg.defaultMarkdownDirname} \
            "$link"
        fi

        # Generate persistent secrets if they don't exist yet
        if [ ! -f ${outlineSecretKeyFile} ]; then
          ${pkgs.coreutils}/bin/head -c 32 /dev/urandom | \
            ${pkgs.coreutils}/bin/base64 > ${outlineSecretKeyFile}
        fi
        if [ ! -f ${outlineUtilsSecretFile} ]; then
          ${pkgs.coreutils}/bin/head -c 32 /dev/urandom | \
            ${pkgs.coreutils}/bin/base64 > ${outlineUtilsSecretFile}
        fi
        if [ ! -f ${dexClientSecretFile} ]; then
          ${pkgs.coreutils}/bin/printf '%s' \
            'd73ea252ff5c31cce30b165838a608e83e56403f6e9d35d36287daabf9b6dcfd' \
            > ${dexClientSecretFile}
        fi
      '';
    };

    # Dex OIDC provider for local email/password authentication
    services.dex = {
      enable = true;
      settings = {
        issuer = dexIssuer;
        # Use memory storage: no filesystem state needed since all config is
        # declarative (staticPasswords + staticClients)
        storage.type = "memory";
        web.http = "127.0.0.1:${builtins.toString dexPort}";
        enablePasswordDB = true;
        staticClients = [
          {
            id = dexClientId;
            name = "Outline";
            redirectURIs = [
              "http://${config.networking.hostName}.local/auth/oidc.callback"
            ];
            secretFile = dexClientSecretFile;
          }
        ];
        staticPasswords = [
          {
            email = "andrew.torgesen@gmail.com";
            hash = "$2b$12$NbLugPmG3OCPZkem21iDmu3RMfYhMR6SLvp6J0yoKsYbokWx68k3q";
            username = "andrew";
            userID = "13c8ce7b-98ec-4455-81ae-7be607fdbce3";
          }
        ];
      };
    };

    # PostgreSQL: the NixOS outline module only enables this when databaseUrl ==
    # "local", which we can't use (it omits the username, causing libpq to auth
    # as the OS user "andrew" instead of the "outline" role).  Replicate what
    # the module would have done, but with our explicit databaseUrl.
    services.postgresql = {
      enable = true;
      ensureUsers = [
        {
          name = "outline";
          ensureDBOwnership = true;
        }
      ];
      ensureDatabases = [ "outline" ];
      # The service runs as "andrew" but connects as role "outline", so peer
      # auth would fail (OS user != role name). Use trust for this role on the
      # local socket so no password is needed.
      authentication = lib.mkAfter ''
        local outline outline trust
      '';
    };

    # Outline wiki server
    services.outline = {
      enable = true;
      publicUrl = "http://${config.networking.hostName}.local";
      port = outlinePort;
      forceHttps = false;
      secretKeyFile = outlineSecretKeyFile;
      utilsSecretFile = outlineUtilsSecretFile;
      # Explicitly specify the postgresql role so that libpq doesn't default to
      # the OS username ("andrew"), which has no corresponding PostgreSQL role.
      # The NixOS outline module always creates role "outline" regardless of
      # the services.outline.user setting.
      databaseUrl = "postgres://outline@localhost/outline?host=/run/postgresql&sslmode=disable";
      storage = {
        storageType = "local";
        localRootDir = "${cfg.rootDir}/outlineDocs";
      };
      oidcAuthentication = {
        authUrl = "${dexIssuer}/auth";
        tokenUrl = "${dexIssuer}/token";
        userinfoUrl = "${dexIssuer}/userinfo";
        clientId = dexClientId;
        clientSecretFile = dexClientSecretFile;
        scopes = [
          "openid"
          "email"
          "profile"
        ];
        usernameClaim = "email";
        displayName = "Local Login";
      };
    };

    # Ordering: outline needs outline-setup, dex, and postgresql running first
    systemd.services.outline = {
      after = [
        "outline-setup.service"
        "dex.service"
        "postgresql.service"
      ];
      requires = [
        "outline-setup.service"
        "dex.service"
        "postgresql.service"
      ];
    };

    # Nginx reverse proxy: expose Outline on the local virtual host.
    # Outline uses absolute asset paths (/static/, /images/, /fonts/,
    # /locales/, /api/, etc.) regardless of the publicUrl subpath, so the
    # simplest correct approach is to proxy all traffic on this vhost to
    # Outline.
    machines.base.runWebServer = true;
    services.nginx.virtualHosts."${config.networking.hostName}.local" = {
      locations."/" = {
        proxyPass = "http://127.0.0.1:${builtins.toString outlinePort}";
        proxyWebsockets = true;
        extraConfig = ''
          proxy_set_header Host $host;
          proxy_set_header X-Real-IP $remote_addr;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto $scheme;
        '';
      };
    };
  };
}
