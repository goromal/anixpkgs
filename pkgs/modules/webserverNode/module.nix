{
  config,
  pkgs,
  lib,
  ...
}:
with import ../../nixos/dependencies.nix;
let
  cfg = config.machines.base;
  themeCss = pkgs.writeText "anix-theme.css" ''
    :root[data-anix-theme="light"] { color-scheme: light; --anix-bg: #f5f7f9; --anix-surface: #ffffff; --anix-surface-alt: #eef3f7; --anix-text: #17212b; --anix-muted: #5f6b76; --anix-border: #cbd5df; --anix-link: #0069d9; --anix-shadow: rgba(31,48,61,.16); --anix-success-bg: #e7f4e8; --anix-success: #245c2a; --anix-warning-bg: #fff3cd; --anix-warning: #664d03; --anix-danger-bg: #f8d7da; --anix-danger: #842029; }
    :root[data-anix-theme="dark"] { color-scheme: dark; --anix-bg: #111827; --anix-surface: #1f2937; --anix-surface-alt: #263449; --anix-text: #e5e7eb; --anix-muted: #b6c2d0; --anix-border: #52647b; --anix-link: #7cc0ff; --anix-shadow: rgba(0,0,0,.45); --anix-success-bg: #153b2a; --anix-success: #9be7b4; --anix-warning-bg: #453817; --anix-warning: #ffe08a; --anix-danger-bg: #4a2028; --anix-danger: #ffb4bd; --bs-body-color: var(--anix-text); --bs-body-bg: var(--anix-bg); --bs-secondary-color: var(--anix-muted); --bs-secondary-bg: var(--anix-surface-alt); --bs-tertiary-bg: var(--anix-surface-alt); --bs-emphasis-color: #ffffff; --bs-heading-color: #f1f5f9; --bs-border-color: var(--anix-border); --bs-card-bg: var(--anix-surface); --bs-modal-bg: var(--anix-surface); }
    :root[data-anix-theme] body { background: var(--anix-bg) !important; color: var(--anix-text) !important; }
    :root[data-anix-theme] :is(.container:not(body),.card,.panel,.section,.service-group,.service-card,.question-card,.detail-card,.compare-card,.fetch-card,.region-card,.setup-panel,.debug-panel,.login-card,.modal-content,.modal-box,.modal,.list-group-item,.workspace,.repo,.add-card,.browser,.entry,.passage,.controls-section,.upload-section,.edit-points-section,.dir-picker,.ref-section,.rankables-config,.stampables-config,.type-tab,.type-section,.controls,.header,.map-container,.feedback,.account,.image-container,.autoplay-bar,#videoSection,.video-info,.file-meta,.realpath-value) { background-color: var(--anix-surface) !important; color: var(--anix-text) !important; border-color: var(--anix-border) !important; box-shadow: 0 2px 10px var(--anix-shadow); }
    :root[data-anix-theme] :is(input,textarea,select,.form-control,.form-select,.blank-input,.sa-textarea,.ws-input,.stamp-search) { background-color: var(--anix-surface-alt) !important; color: var(--anix-text) !important; border-color: var(--anix-border) !important; }
    :root[data-anix-theme] :is(table,thead,tbody,tr,th,td,.table,.ref-table,.dir-list,.rank-list,.stamp-list,.watch-list,.q-list) { background-color: var(--anix-surface) !important; color: var(--anix-text) !important; border-color: var(--anix-border) !important; }
    :root[data-anix-theme] :is(pre,code,.log-box,.prog-out,.orch-restart-log,.rank-txt,.terminal) { background-color: var(--anix-surface-alt) !important; color: var(--anix-text) !important; border-color: var(--anix-border) !important; }
    :root[data-anix-theme="dark"] form { background-color: var(--anix-surface) !important; color: var(--anix-text) !important; border-color: var(--anix-border) !important; }
    :root[data-anix-theme] :is(.text-muted,.muted,.description,.subtitle,.hint,.meta,.help,.realpath-label,.upload-hint,.loading-message,.dir-list-empty,.empty,.no-regions) { color: var(--anix-muted) !important; }
    :root[data-anix-theme] a:not(.btn):not(.button):not(.service-card) { color: var(--anix-link); }
    :root[data-anix-theme] hr { border-color: var(--anix-border); }
    :root[data-anix-theme="light"] .panel :is(h2,label) { color: var(--anix-text) !important; }
    :root[data-anix-theme="light"] .panel :is(p:not(.error):not(.notice),small) { color: var(--anix-muted) !important; }
    :root[data-anix-theme="light"] .session { background: var(--anix-surface-alt) !important; color: var(--anix-text) !important; border-color: var(--anix-border) !important; }
    :root[data-anix-theme="light"] main > nav a.active { color: #ffffff !important; }
    :root[data-anix-theme="dark"] :is(.bg-light,.bg-white) { background-color: var(--anix-surface-alt) !important; color: var(--anix-text) !important; }
    :root[data-anix-theme="dark"] .service-group { background-image: none !important; }
    :root[data-anix-theme="dark"] :is(.survey-results,.survey-section) { background: var(--anix-surface) !important; color: var(--anix-text) !important; }
    :root[data-anix-theme="dark"] .survey-results { border-color: var(--anix-border) !important; }
    :root[data-anix-theme] .survey-summary { color: #111827 !important; }
    :root[data-anix-theme="dark"] .survey-empty { background: var(--anix-surface-alt) !important; color: var(--anix-muted) !important; }
    :root[data-anix-theme="dark"] .survey-eyebrow { color: #c4b5fd !important; }
    :root[data-anix-theme="dark"] :is(.survey-subtitle,.survey-legend span,.survey-date-span) { color: var(--anix-muted) !important; }
    :root[data-anix-theme="dark"] .question-label { color: var(--anix-text) !important; }
    :root[data-anix-theme="dark"] :is(h1,h2,h3,h4,h5,h6,label,legend,summary,.form-label,.question-text,.detail-question,.detail-row,.score-label,.chunk-shown,.ctrl-info,.ref,.context,.verse-num,.sort-link,.csv-group-header,.realpath-label,.modal-header,.modal-body,.dir-picker-path,.dir-btn,.edit-point-row,.txt-name,.progress-label,.city-prompt,.score,.region-title,.video-title,#videoTitle) { color: var(--anix-text) !important; }
    :root[data-anix-theme="dark"] :is(.question-num,.sub,.count,.opt,.kw-empty,.status-pending,.file-size,.video-meta,.duration,.crop-info,.edit-point-time,.cal-header,.csv-desc,.modal-close,figcaption,#crop-label,#fit-note,#fit-result,#modal-path,#csv-save-status) { color: var(--anix-muted) !important; }
    :root[data-anix-theme="dark"] :is(.dir-picker-header,.dir-picker-actions,.option-label:hover,.arch-item:hover,.stamp-list a:hover,.browser .entry:hover,#modal-list li:hover,.debug-info,.add-city-form,.job-detail-box,.progress-track,.progress,.tab,.cal-cell,.crop-info,.flash,#status,#csv-add-btn) { background-color: var(--anix-surface-alt) !important; color: var(--anix-text) !important; border-color: var(--anix-border) !important; }
    :root[data-anix-theme="dark"] :is(.verse.christ-ref,.detail-correct,.status-success,.status-downloading,.status-complete,.notice:not(.error),td.ok,#status.running) { background-color: var(--anix-success-bg) !important; color: var(--anix-success) !important; border-color: var(--anix-success) !important; }
    :root[data-anix-theme="dark"] :is(.detail-partial,.error-message,.status-warning,.status-paused,.banner,#csv-dirty-banner) { background-color: var(--anix-warning-bg) !important; color: var(--anix-warning) !important; border-color: var(--anix-warning) !important; }
    :root[data-anix-theme="dark"] :is(.detail-wrong,.status-error,.status-interrupted,.notice.error,td.error,.flash-error,#status.stopped) { background-color: var(--anix-danger-bg) !important; color: var(--anix-danger) !important; border-color: var(--anix-danger) !important; }
    :root[data-anix-theme="dark"] :is(.status-badge,.status-metadata,.status-queued,.status-cancelled) { background-color: var(--anix-surface-alt) !important; color: var(--anix-muted) !important; border-color: var(--anix-border) !important; }
    :root[data-anix-theme="dark"] :is(.ok,.status-done) { color: var(--anix-success) !important; }
    :root[data-anix-theme="dark"] .error { color: var(--anix-danger) !important; }
    :root[data-anix-theme="dark"] :is(.badge-rote,.badge-multiple_choice,.badge-short_answer,.score-high,.score-mid,.score-low,.tag-chip,.tag) { background-color: var(--anix-surface-alt) !important; color: var(--anix-text) !important; border-color: var(--anix-border) !important; }
    :root[data-anix-theme="dark"] :is(.btn-secondary,.secondary,.skip) { background-color: #3b4a5e !important; color: #f1f5f9 !important; border-color: #64748b !important; }
    :root[data-anix-theme="dark"] #loading-overlay { background: rgba(17,24,39,.9) !important; }
    :root[data-anix-theme="dark"] .title-icon { filter: brightness(0) invert(1); }
    :root[data-anix-theme="dark"] :is([style*="color:#333"],[style*="color: #333"],[style*="color:#444"],[style*="color: #444"],[style*="color:#555"],[style*="color: #555"],[style*="color:#666"],[style*="color: #666"],[style*="color:#777"],[style*="color: #777"],[style*="color:#888"],[style*="color: #888"],[style*="color:#aaa"],[style*="color: #aaa"],[style*="color:#1a3a5c"],[style*="color: #1a3a5c"],[style*="color:#2c3e50"],[style*="color: #2c3e50"]) { color: var(--anix-muted) !important; }
  '';
  # No single quotes: nginx wraps each sub_filter replacement in single quotes.
  themeHead = lib.replaceStrings [ "\n" ] [ " " ] ''
    <link rel="stylesheet" href="/anix-theme.css">
    <script>(function(){var c=document.cookie.split("; ");var m=c.find(function(v){return v.indexOf("anix-theme=")===0;});var t=m?m.slice(11):null;try{t=t||localStorage.getItem("anix-theme");}catch(e){}if(t!=="light"&&t!=="dark"){t=window.matchMedia&&window.matchMedia("(prefers-color-scheme: dark)").matches?"dark":"light";}document.documentElement.dataset.anixTheme=t;document.documentElement.setAttribute("data-bs-theme",t);})();</script></head>
  '';
  themeCssLocation = {
    alias = themeCss;
    extraConfig = ''
      default_type text/css;
      add_header Cache-Control "no-cache";
    '';
  };
  pageControls =
    homeBase: showThemeToggle:
    ''<script>(function(){if(!document.querySelector("meta[name=viewport]")){var mv=document.createElement("meta");mv.name="viewport";mv.content="width=device-width,initial-scale=1";(document.head||document.documentElement).appendChild(mv);}if(!document.body)return;var b=${homeBase};var h=document.createElement("div");h.setAttribute("aria-label","Page controls");h.style.cssText="all:initial;position:fixed;bottom:20px;right:20px;z-index:2147483647;display:flex;gap:10px";var s="display:flex;align-items:center;justify-content:center;width:44px;height:44px;background:#007bff;color:white;border:0;border-radius:50%;font:22px/1 sans-serif;text-decoration:none;box-shadow:0 2px 8px rgba(0,0,0,.35);cursor:pointer";${lib.optionalString showThemeToggle ''var t=document.createElement("button");t.type="button";t.style.cssText=s;function u(){var d=document.documentElement.dataset.anixTheme==="dark";t.textContent=d?"☀":"☾";t.title=d?"Use light theme":"Use dark theme";t.setAttribute("aria-label",t.title);t.setAttribute("aria-pressed",String(d));}t.addEventListener("click",function(){var n=document.documentElement.dataset.anixTheme==="dark"?"light":"dark";document.documentElement.dataset.anixTheme=n;document.documentElement.setAttribute("data-bs-theme",n);document.cookie="anix-theme="+n+"; Path=/; Max-Age=31536000; SameSite=Lax";try{localStorage.setItem("anix-theme",n);}catch(e){}u();});u();h.appendChild(t);''}var a=document.createElement("a");a.href=b;a.title="Home";a.setAttribute("aria-label","Home");a.style.cssText=s;var i=document.createElement("img");i.src=b+"icons/house.svg";i.alt="";i.style.cssText="width:20px;height:20px;display:block;filter:invert(1)";a.appendChild(i);h.appendChild(a);document.body.appendChild(h);})();</script></body>'';
  pageControlsMain = pageControls ''"/"'' true;
  pageControlsOwnPort = pageControls ''window.location.protocol+"//"+window.location.hostname+":${toString cfg.webServerSecurePort}/"'' true;
  pageControlsOwnPortHomeOnly = pageControls ''window.location.protocol+"//"+window.location.hostname+":${toString cfg.webServerSecurePort}/"'' false;
  ownPortPageControlVhosts = lib.listToAttrs (
    map (s: {
      name = "${config.networking.hostName}.local:${toString s.port}";
      value.extraConfig = ''
        ${lib.optionalString (s.name != "folio") "sub_filter </head> '${themeHead}';"}
        sub_filter </body> '${
          if s.name == "folio" then pageControlsOwnPortHomeOnly else pageControlsOwnPort
        }';
        sub_filter_once on;
        proxy_set_header Accept-Encoding "";
      '';
      value.locations = lib.optionalAttrs (s.name != "folio") { "= /anix-theme.css" = themeCssLocation; };
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
            sub_filter </body> '${pageControlsMain}';
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
                      * { box-sizing: border-box; }
                      body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif; max-width: 800px; margin: 50px auto; padding: 20px; background: #f5f7f9; color: #17212b; }
                      .container { background: white; padding: 30px; border: 1px solid #dce3e8; border-radius: 20px; box-shadow: 0 12px 34px rgba(31,48,61,0.08); }
                      h1 { color: #333; margin-top: 0; display: flex; align-items: center; gap: 14px; }
                      h2 { color: #075eac; font-size: 1.05rem; margin: 0 0 12px; }
                      .title-icon { width: 28px; height: 28px; flex-shrink: 0; filter: invert(18%) sepia(0%) saturate(0%) hue-rotate(0deg) brightness(40%) contrast(100%); }
                      .service-group { background: linear-gradient(135deg, #f3f8fd, #fff 70%); border: 2px solid #2680d9; border-radius: 16px; margin-top: 18px; padding: 18px; }
                      ul { list-style: none; margin: 0; padding: 0; }
                      li + li { margin-top: 9px; }
                      .service-card { display: flex; align-items: center; gap: 14px; padding: 13px 15px; background: rgba(255,255,255,0.82); border-radius: 10px; border: 1px solid #dce5ec; text-decoration: none; transition: background 0.15s, border-color 0.15s, transform 0.15s; }
                      .service-card:hover { background: #e8f2fc; border-color: #78ade0; transform: translateY(-1px); }
                      .service-icon { width: 22px; height: 22px; flex-shrink: 0; filter: invert(29%) sepia(96%) saturate(2145%) hue-rotate(204deg) brightness(104%) contrast(101%); }
                      .service-info { display: flex; flex-direction: column; }
                      .service-name { color: #007bff; font-weight: 600; font-size: 1em; }
                      .description { color: #666; font-size: 0.9em; margin-top: 2px; }
                      @media (max-width: 575px) {
                        body { margin: 0 auto; padding: 14px; }
                        .container { padding: 18px; }
                        .service-group { padding: 14px; }
                      }
                    </style>
                  </head>
                  <body>
                    <div class="container">
                      <h1><img src="/icons/server.svg" class="title-icon" alt="server">${hostname} Services</h1>
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
                      sub_filter </body> '${pageControlsMain}';
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
            }
            // faviconLocations
            // pageControlLocations;
        };
      }
      // ownPortPageControlVhosts;
    };
  };
}
