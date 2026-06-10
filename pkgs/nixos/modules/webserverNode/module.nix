{
  config,
  pkgs,
  lib,
  ...
}:
with import ../../dependencies.nix;
let
  cfg = config.machines.base;
  # Built entirely via JS DOM so element.style overrides any page stylesheet.
  # No single quotes (nginx wraps replacement in single quotes).
  homeButton = ''<script>(function(){if(!document.querySelector("meta[name=viewport]")){var mv=document.createElement("meta");mv.name="viewport";mv.content="width=device-width,initial-scale=1";(document.head||document.documentElement).appendChild(mv);}if(!document.body)return;var h=document.createElement("div");h.style.cssText="all:initial;position:fixed;bottom:20px;right:20px;z-index:2147483647";var a=document.createElement("a");a.href="/";a.title="Home";a.style.cssText="display:flex;align-items:center;justify-content:center;width:44px;height:44px;background:#007bff;border-radius:50%;text-decoration:none;box-shadow:0 2px 8px rgba(0,0,0,.25)";var i=document.createElement("img");i.src="/icons/house.svg";i.style.cssText="width:20px;height:20px;display:block;filter:invert(1)";a.appendChild(i);h.appendChild(a);document.body.appendChild(h);})();</script></body>'';
in
{
  config = lib.mkIf cfg.runWebServer {
    services.nginx = {
      enable = true;
      user = "andrew";
      group = "dev";
      virtualHosts."${config.networking.hostName}.local" = {
        # Support both HTTP and HTTPS (no forced redirect)
        forceSSL = false;
        addSSL = true;
        sslCertificateKey = "${cfg.homeDir}/secrets/vpn/key.pem";
        sslCertificate = "${cfg.homeDir}/secrets/vpn/chain.pem";
        # Server-level fallback: covers locations without their own sub_filter
        # (e.g. wiki's ~ \.php$ FastCGI location). The homeButtonLocations entries
        # define their own sub_filter, which takes precedence per nginx inheritance rules.
        extraConfig = ''
          sub_filter </body> '${homeButton}';
          sub_filter_once on;
        '';
        listen = [
          {
            addr = "0.0.0.0";
            port = cfg.webServerInsecurePort;
          }
          {
            addr = "0.0.0.0";
            port = cfg.webServerSecurePort;
            ssl = true;
          }
        ];

        # Landing page listing all available services + per-service favicon endpoints.
        # Static content is written into a Nix store directory; nginx serves it via
        # root+try_files (avoids alias_traversal gixy warning and return-length limits).
        locations =
          let
            hostname = config.networking.hostName;
            services = lib.sort (a: b: lib.toLower a.name < lib.toLower b.name) cfg.webServices;
            serviceIcon =
              s:
              if s.icon != "" then
                ''<img src="/icons/${s.icon}.svg" class="service-icon" alt="${s.icon}">''
              else
                "";
            serviceLinks = lib.concatMapStringsSep "\n" (
              s:
              if s.path == "#" then
                let
                  portMatch = builtins.match ".*\\(port ([0-9]+)\\).*" s.description;
                  port = if portMatch != null then builtins.head portMatch else "";
                in
                ''<li><a href="#" class="service-card" onclick="window.location.href=window.location.protocol+String.fromCharCode(47,47)+window.location.hostname+String.fromCharCode(58)+${lib.escapeShellArg port}+String.fromCharCode(47); return false;">${serviceIcon s}<span class="service-info"><span class="service-name">${s.name}</span><span class="description">${s.description}</span></span></a></li>''
              else
                ''<li><a href="${s.path}" class="service-card">${serviceIcon s}<span class="service-info"><span class="service-name">${s.name}</span><span class="description">${s.description}</span></span></a></li>''
            ) services;
            # Build one directory containing index.html and per-service favicon.svg files
            staticRoot = pkgs.runCommand "nginx-static-${hostname}" { } (
              ''
                mkdir -p $out
                cat > $out/index.html << 'HTMLEOF'
                <!DOCTYPE html>
                <html>
                <head>
                  <meta charset="UTF-8">
                  <meta name="viewport" content="width=device-width, initial-scale=1.0">
                  <title>${hostname} Services</title>
                  <link rel="icon" type="image/svg+xml" href="/favicon.svg">
                  <style>
                    body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif; max-width: 800px; margin: 50px auto; padding: 20px; background: #f5f5f5; }
                    .container { background: white; padding: 30px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
                    h1 { color: #333; margin-top: 0; display: flex; align-items: center; gap: 14px; }
                    .title-icon { width: 28px; height: 28px; flex-shrink: 0; filter: invert(18%) sepia(0%) saturate(0%) hue-rotate(0deg) brightness(40%) contrast(100%); }
                    ul { list-style: none; padding: 0; }
                    li { margin: 12px 0; }
                    .service-card { display: flex; align-items: center; gap: 14px; padding: 14px 16px; background: #f9f9f9; border-radius: 8px; border: 2px solid #007bff; text-decoration: none; transition: background 0.15s, border-color 0.15s; }
                    .service-card:hover { background: #e8f0fe; border-color: #0056b3; }
                    .service-icon { width: 22px; height: 22px; flex-shrink: 0; filter: invert(29%) sepia(96%) saturate(2145%) hue-rotate(204deg) brightness(104%) contrast(101%); }
                    .service-info { display: flex; flex-direction: column; }
                    .service-name { color: #007bff; font-weight: 600; font-size: 1em; }
                    .description { color: #666; font-size: 0.9em; margin-top: 2px; }
                  </style>
                </head>
                <body>
                  <div class="container">
                    <h1><img src="/icons/server.svg" class="title-icon" alt="server">${hostname} Services</h1>
                    <ul>
                ${serviceLinks}
                    </ul>
                  </div>
                </body>
                </html>
                HTMLEOF
              ''
              +
                # Copy per-service favicon SVGs
                lib.concatMapStrings (
                  s:
                  lib.optionalString (s.faviconSvg != null && s.path != "#") (
                    let
                      dir = lib.removePrefix "/" (lib.removeSuffix "/" s.path);
                    in
                    "mkdir -p $out/${dir} && cp ${s.faviconSvg} $out/${dir}/favicon.svg\n"
                  )
                ) cfg.webServices
              +
                # Copy root-page icon SVGs from anixdata (deduped by icon name)
                (
                  let
                    iconNames = lib.unique (lib.filter (n: n != "") (map (s: s.icon) services));
                    fa6 = anixpkgs.pkgData.icons.fa6-solid;
                  in
                  "mkdir -p $out/icons\n"
                  + lib.concatMapStrings (name: "cp ${fa6.${name}.data} $out/icons/${name}.svg\n") iconNames
                  + "cp ${fa6.house.data} $out/icons/house.svg\n"
                  + "cp ${fa6.server.data} $out/icons/server.svg\n"
                  + "cp ${fa6.server.data} $out/favicon.svg\n"
                )
            );
            rootPage = {
              root = "${staticRoot}";
              tryFiles = "/index.html =404";
              extraConfig = "add_header Content-Type text/html;";
            };
            iconsLocation = {
              "/icons/" = {
                root = "${staticRoot}";
                tryFiles = "$uri =404";
                extraConfig = ''add_header Content-Type "image/svg+xml";'';
              };
            };
            faviconLocations = lib.listToAttrs (
              lib.concatMap (
                s:
                lib.optional (s.faviconSvg != null && s.path != "#") (
                  let
                    dir = lib.removePrefix "/" (lib.removeSuffix "/" s.path);
                  in
                  {
                    name = "${s.path}favicon.svg";
                    value = {
                      root = "${staticRoot}";
                      tryFiles = "/${dir}/favicon.svg =404";
                      extraConfig = ''add_header Content-Type "image/svg+xml";'';
                    };
                  }
                )
              ) cfg.webServices
            );
            # homeButton defined in the outer let; accessible here via lexical scoping.
            # extraConfig is types.lines so this concatenates with each service's existing config.
            homeButtonLocations = lib.listToAttrs (
              lib.concatMap (
                s:
                lib.optional (s.path != "#") {
                  name = s.path;
                  value.extraConfig = ''
                    sub_filter </body> '${homeButton}';
                    sub_filter_once on;
                    proxy_set_header Accept-Encoding "";
                  '';
                }
              ) services
            );
            rootFaviconLocation = {
              "= /favicon.svg" = {
                root = "${staticRoot}";
                tryFiles = "/favicon.svg =404";
                extraConfig = ''add_header Content-Type "image/svg+xml";'';
              };
            };
          in
          {
            "= /" = rootPage;
          }
          // iconsLocation
          // rootFaviconLocation
          // faviconLocations
          // homeButtonLocations;
      };
    };
  };
}
