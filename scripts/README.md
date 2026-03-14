# Scripts

This directory may contain source scripts used during development or for creating Nix packages.

Most utility scripts are packaged in `pkgs/bash-packages/` and made available system-wide on configured NixOS machines, rather than being run directly from this directory.

## Note on Script Packaging

Previously, this directory contained standalone scripts. These have been migrated to proper Nix packages in `pkgs/bash-packages/` for better:
- Dependency management
- System-wide availability
- Integration with NixOS configurations
- Documentation and discoverability

For example, the SSL certificate generation script is now packaged as `generate-local-ssl-certs` and is automatically available on any machine with `runWebServer = true`. See the [Local SSL Setup documentation](../docs/src/local-ssl-setup.md) for usage information.
