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
  };
}
