{
  config,
  pkgs,
  lib,
  ...
}:
with import ../../nixos/dependencies.nix;
let
  cfg = config.machines.base;
  cssLocation = asset: {
    alias = asset;
    extraConfig = ''
      default_type text/css;
      add_header Cache-Control "no-cache";
    '';
  };
  themeCssLocation = cssLocation pkgs.pkgData.web.anix-theme.data;
  landingCssLocation = cssLocation pkgs.pkgData.web.landing.data;
  pageControlsCssLocation = cssLocation pkgs.pkgData.web.page-controls.data;
  # No single quotes: nginx wraps each sub_filter replacement in single quotes.
  themeHead = lib.replaceStrings [ "\n" ] [ " " ] ''
    <link rel="stylesheet" href="/anix-theme.css">
    <link rel="stylesheet" href="/anix-page-controls.css">
    <script>(function(){var c=document.cookie.split("; ");var m=c.find(function(v){return v.indexOf("anix-theme=")===0;});var t=m?m.slice(11):null;try{t=t||localStorage.getItem("anix-theme");}catch(e){}if(t!=="light"&&t!=="dark"){t=window.matchMedia&&window.matchMedia("(prefers-color-scheme: dark)").matches?"dark":"light";}document.documentElement.dataset.anixTheme=t;document.documentElement.setAttribute("data-bs-theme",t);})();</script></head>
  '';
  pageControlsHead = ''<link rel="stylesheet" href="/anix-page-controls.css"></head>'';
  pageControls =
    homeBase: showThemeToggle: showHome:
    ''<script>(function(){if(!document.querySelector("meta[name=viewport]")){var mv=document.createElement("meta");mv.name="viewport";mv.content="width=device-width,initial-scale=1";(document.head||document.documentElement).appendChild(mv);}if(!document.body)return;var b=${homeBase};var h=document.createElement("div");h.setAttribute("aria-label","Page controls");h.className="anix-page-controls";${lib.optionalString showThemeToggle ''var t=document.createElement("button");t.type="button";t.className="anix-page-control";function u(){var d=document.documentElement.dataset.anixTheme==="dark";t.textContent=d?"☀":"☾";t.title=d?"Use light theme":"Use dark theme";t.setAttribute("aria-label",t.title);t.setAttribute("aria-pressed",String(d));}t.addEventListener("click",function(){var n=document.documentElement.dataset.anixTheme==="dark"?"light":"dark";document.documentElement.dataset.anixTheme=n;document.documentElement.setAttribute("data-bs-theme",n);document.cookie="anix-theme="+n+"; Path=/; Max-Age=31536000; SameSite=Lax";try{localStorage.setItem("anix-theme",n);}catch(e){}u();});u();h.appendChild(t);''}${lib.optionalString showHome ''var a=document.createElement("a");a.href=b;a.title="Home";a.setAttribute("aria-label","Home");a.className="anix-page-control";var i=document.createElement("img");i.src=b+"icons/house.svg";i.alt="";a.appendChild(i);h.appendChild(a);''}document.body.appendChild(h);})();</script></body>'';
  pageControlsMain = pageControls ''"/"'' true;
  pageControlsOwnPort = pageControls ''window.location.protocol+"//"+window.location.hostname+":${toString cfg.webServerSecurePort}/"'' true;
  pageControlsOwnPortHomeOnly = pageControls ''window.location.protocol+"//"+window.location.hostname+":${toString cfg.webServerSecurePort}/"'' false;
  ownPortPageControlVhosts = lib.listToAttrs (
    map (s: {
      name = "${config.networking.hostName}.local:${toString s.port}";
      value.extraConfig = ''
        sub_filter </head> '${if s.name == "folio" then pageControlsHead else themeHead}';
        sub_filter </body> '${(if s.name == "folio" then pageControlsOwnPortHomeOnly else pageControlsOwnPort) s.homeButton}';
        sub_filter_once on;
        proxy_set_header Accept-Encoding "";
      '';
      value.locations = {
        "= /anix-page-controls.css" = pageControlsCssLocation;
      }
      // lib.optionalAttrs (s.name != "folio") { "= /anix-theme.css" = themeCssLocation; };
    }) (lib.filter (s: s.port != null) cfg.webServices)
  );
in
{
  config = lib.mkIf cfg.runWebServer {
    services.nginx = {
      enable = true;
      user = "andrew";
      group = "dev";
      virtualHosts = {
        "${config.networking.hostName}.local" = {
          # Support both HTTP and HTTPS (no forced redirect)
          forceSSL = false;
          addSSL = true;
          sslCertificateKey = "${cfg.homeDir}/secrets/vpn/key.pem";
          sslCertificate = "${cfg.homeDir}/secrets/vpn/chain.pem";
          # Server-level fallback: covers locations without their own sub_filter
          # (e.g. wiki's ~ \.php$ FastCGI location). The pageControlLocations entries
          # define their own sub_filter, which takes precedence per nginx inheritance rules.
          extraConfig = ''
            sub_filter </head> '${themeHead}';
            sub_filter </body> '${pageControlsMain true}';
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
              tags = lib.sort (a: b: lib.toLower a < lib.toLower b) (lib.unique (map (s: s.tag) services));
              serviceIcon =
                s:
                if s.icon != "" then
                  ''<img src="/icons/${s.icon}.svg" class="service-icon" alt="${s.icon}">''
                else
                  "";
              serviceLinks =
                selectedServices:
                lib.concatMapStringsSep "\n" (
                  s:
                  if s.port != null then
                    ''<li><a href="#" class="service-card" onclick="window.location.href=window.location.protocol+String.fromCharCode(47,47)+window.location.hostname+String.fromCharCode(58)+${toString s.port}+String.fromCharCode(47); return false;">${serviceIcon s}<span class="service-info"><span class="service-name">${s.name}</span><span class="description">${s.description}</span></span></a></li>''
                  else
                    ''<li><a href="${s.path}" class="service-card">${serviceIcon s}<span class="service-info"><span class="service-name">${s.name}</span><span class="description">${s.description}</span></span></a></li>''
                ) selectedServices;
              serviceGroups = lib.concatMapStringsSep "\n" (tag: ''
                <section class="service-group">
                  <h2>${tag}</h2>
                  <ul>
                    ${serviceLinks (lib.filter (s: s.tag == tag) services)}
                  </ul>
                </section>
              '') tags;
              nexusLink =
                lib.optionalString (cfg.nexusUrl != null)
                  ''<a href="${cfg.nexusUrl}" class="nexus-link" title="All LAN machines"><img src="/icons/network-wired.svg" class="service-icon" alt="">Nexus</a>'';
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
                    <link rel="stylesheet" href="/anix-landing.css">
                  </head>
                  <body>
                    <div class="container">
                      <div class="title-row">
                        <h1><img src="/icons/server.svg" class="title-icon" alt="server">${hostname} Services</h1>
                        ${nexusLink}
                      </div>
                  ${serviceGroups}
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
                      iconNames = lib.unique (
                        lib.filter (n: n != "") (map (s: s.icon) services)
                        ++ lib.optional (cfg.nexusUrl != null) "network-wired"
                      );
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
              # Shared theme and controls are defined in the outer let.
              # extraConfig is types.lines so this concatenates with each service's existing config.
              pageControlLocations = lib.listToAttrs (
                lib.concatMap (
                  s:
                  lib.optional (s.path != "#") {
                    name = s.path;
                    value.extraConfig = ''
                      sub_filter </head> '${
                        lib.optionalString (
                          s.faviconSvg != null
                        ) ''<link rel="icon" type="image/svg+xml" href="${s.path}favicon.svg">''
                      }${themeHead}';
                      sub_filter </body> '${pageControlsMain s.homeButton}';
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
            // {
              "= /anix-theme.css" = themeCssLocation;
              "= /anix-landing.css" = landingCssLocation;
              "= /anix-page-controls.css" = pageControlsCssLocation;
            }
            // faviconLocations
            // pageControlLocations;
        };
      }
      // ownPortPageControlVhosts;
    };
  };
}
