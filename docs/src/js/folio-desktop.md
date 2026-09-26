# folio-desktop

folio Electron desktop shell (loads the served SPA at /folio).

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

