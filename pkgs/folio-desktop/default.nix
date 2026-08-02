{
  stdenvNoCC,
  makeWrapper,
  electron,
  pkg-src,
}:
stdenvNoCC.mkDerivation {
  pname = "folio-desktop";
  version = "0.0.1";
  src = "${pkg-src}/desktop";

  nativeBuildInputs = [ makeWrapper ];
  dontBuild = true;

  # Thin shell: wrap nixpkgs' prebuilt electron over the desktop/ app dir (main.js
  # loads the backend-served SPA at http://localhost:6666/folio). No electron-builder.
  installPhase = ''
    runHook preInstall

    mkdir -p $out/share/folio-desktop
    cp main.js package.json $out/share/folio-desktop/

    makeWrapper ${electron}/bin/electron $out/bin/folio-desktop \
      --add-flags $out/share/folio-desktop

    mkdir -p $out/share/applications
    cat > $out/share/applications/folio.desktop <<EOF
    [Desktop Entry]
    Type=Application
    Name=folio
    Comment=Book Study Companion
    Exec=$out/bin/folio-desktop
    Icon=accessories-dictionary
    Terminal=false
    Categories=Office;Education;
    EOF

    runHook postInstall
  '';

  meta = {
    description = "folio Electron desktop shell (loads the served SPA at /folio).";
    mainProgram = "folio-desktop";
  };
}
