{
  buildPythonPackage,
  setuptools,
  fastapi,
  uvicorn,
  pydantic,
  ebooklib,
  beautifulsoup4,
  python-multipart,
  httpx,
  pkg-src,
}:
buildPythonPackage {
  pname = "folio-backend";
  version = "0.0.1";
  pyproject = true;
  build-system = [ setuptools ];
  src = "${pkg-src}/backend";
  propagatedBuildInputs = [
    fastapi
    uvicorn
    pydantic
    ebooklib
    beautifulsoup4
    python-multipart
  ];
  nativeCheckInputs = [ httpx ];
  checkPhase = ''
    runHook preCheck
    python -m unittest discover -s tests -v
    runHook postCheck
  '';
  pythonImportsCheck = [ "folio_backend" ];
  meta = {
    description = "folio Book Study Companion backend (FastAPI + SQLite + FTS5 + EPUB ingestion).";
  };
}
