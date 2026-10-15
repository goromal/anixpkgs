{
  stdenvNoCC,
  makeWrapper,
  electron,
  pkgData,
  pkg-src,
  folioPort,
}:
stdenvNoCC.mkDerivation {
  pname = "folio-desktop";
  version = "0.0.1";
  src = "${pkg-src}/desktop";

  nativeBuildInputs = [ makeWrapper ];
  dontBuild = true;

  # Thin shell: wrap nixpkgs' prebuilt electron over the desktop/ app dir (main.js
  # loads the backend-served SPA at http://localhost:$FOLIO_PORT/folio). No
  # electron-builder. FOLIO_PORT must match the backend's internal port and must
  # stay clear of Chromium's restricted-port list (electron is Chromium: it refuses
  # ERR_UNSAFE_PORT ports such as the 6665-6669 IRC range).
  installPhase = ''
    runHook preInstall

    mkdir -p $out/share/folio-desktop
    cp main.js package.json $out/share/folio-desktop/

    makeWrapper ${electron}/bin/electron $out/bin/folio-desktop \
      --set FOLIO_PORT ${toString folioPort} \
      --add-flags $out/share/folio-desktop

    mkdir -p $out/share/applications
    install -Dm644 ${pkgData.icons.apps.folio.data} \
      $out/share/icons/hicolor/512x512/apps/folio.png
    cat > $out/share/applications/folio.desktop <<EOF
    [Desktop Entry]
    Type=Application
    Name=folio
    Comment=Book Study Companion
    Exec=$out/bin/folio-desktop
    Icon=folio
    StartupWMClass=folio-desktop
    Terminal=false
    Categories=Office;Education;
    EOF

    runHook postInstall
  '';

  meta = {
    description = "folio Electron desktop shell (loads the served SPA at /folio).";
    longDescription = ''
      [Repository](https://github.com/goromal/folio)

      A thin Electron desktop wrapper for folio, the Book Study Companion. Rather
      than bundle its own renderer, it wraps nixpkgs' prebuilt `electron` over the
      small `desktop/` app directory (`main.js` + `package.json`); `main.js` simply
      loads the backend-served SPA at `http://localhost:$FOLIO_PORT/folio`. There
      is no `electron-builder` step and no second copy of the frontend.

      `FOLIO_PORT` is baked in at build time from the folio service's internal
      port so the shell targets the same port the backend listens on. The port
      must stay clear of Chromium's restricted-port list — Electron is Chromium
      and refuses `ERR_UNSAFE_PORT` ports such as the 6665-6669 IRC range.

      The package also installs a `folio.desktop` entry and icon, so it appears as
      a normal "folio" application in the desktop menu. On NixOS it is added to
      `environment.systemPackages` when the folio module's `desktop` option is
      enabled.
    '';
    mainProgram = "folio-desktop";
  };
}
