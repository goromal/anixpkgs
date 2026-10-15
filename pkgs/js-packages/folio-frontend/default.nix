{
  buildNpmPackage,
  pkg-src,
}:
buildNpmPackage {
  pname = "folio-frontend";
  version = "0.0.1";
  src = "${pkg-src}/frontend";

  # Deps are pinned by the committed package-lock.json; the generated
  # schema.d.ts / openapi.json are committed too, so the build needs no backend.
  npmDepsHash = "sha256-WUQ7IltSEIzWGwqt2Bz2Dq8VKq1e4oN9Qsw5ma7K+7k=";

  # `npm run build` = `tsc -b && vite build` -> dist/ (static SPA assets).
  installPhase = ''
    runHook preInstall
    mkdir -p $out
    cp -r dist/* $out/
    runHook postInstall
  '';

  meta = {
    description = "folio Book Study Companion web SPA (Vite/React static build).";
    longDescription = ''
      [Repository](https://github.com/goromal/folio)

      The web frontend for folio, the Book Study Companion. This package is the
      compiled single-page application: `npm run build` (`tsc -b && vite build`)
      emits the static `dist/` assets, which are installed verbatim into `$out`.

      The build is fully offline and hermetic. JavaScript dependencies are pinned
      by the committed `package-lock.json` (surfaced to Nix through `npmDepsHash`),
      and the TypeScript API bindings (`schema.d.ts` / `openapi.json`) are
      committed in the source tree, so the SPA compiles without contacting the
      folio backend.

      The resulting static bundle is meant to be served by the folio backend: the
      NixOS folio module points `FOLIO_STATIC_DIR` at this derivation, and the
      backend serves it under `/folio`. It is also what the `folio-desktop`
      Electron shell loads.
    '';
  };
}
