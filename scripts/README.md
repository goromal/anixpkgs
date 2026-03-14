# Scripts

This directory contains utility scripts for managing the anixpkgs system.

## Available Scripts

### generate-local-ssl-certs.sh

Generates self-signed SSL certificates for local LAN HTTPS access.

**Purpose**: Enable HTTPS connections from your phone (or other devices) to your local server without SSL warnings.

**Usage**:
```bash
./generate-local-ssl-certs.sh [server-ip]
```

If `server-ip` is not provided, the script will auto-detect your LAN IP address.

**What it does**:
1. Creates a local Certificate Authority (CA)
2. Generates a server certificate signed by that CA
3. Saves certificates to `~/secrets/vpn/`
4. Displays instructions for installing the CA certificate on your devices

**Important**: After running this script, you must install `~/secrets/vpn/rootCA.pem` on your phone to avoid SSL certificate warnings.

**See also**: [../docs/LOCAL_SSL_SETUP.md](../docs/LOCAL_SSL_SETUP.md) for complete setup instructions.

**Requirements**:
- `mkcert` (run in `nix-shell -p mkcert` if not available)

**Output files**:
- `~/secrets/vpn/rootCA.pem` - CA certificate (install on client devices)
- `~/secrets/vpn/rootCA-key.pem` - CA private key (keep secret!)
- `~/secrets/vpn/chain.pem` - Server certificate
- `~/secrets/vpn/key.pem` - Server private key
