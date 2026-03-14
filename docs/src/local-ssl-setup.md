# Local SSL Setup for LAN Access

This guide explains how to set up HTTPS access to your server from devices on your local network (especially your phone).

## Overview

The server supports **both HTTP and HTTPS** connections:
- **HTTP**: `http://ats.local:80` (or your hostname)
- **HTTPS**: `https://ats.local:443` (or your hostname)

There is **no automatic redirect** from HTTP to HTTPS - you can use either protocol.

## Quick Start

### 1. Generate SSL Certificates

Run the certificate generation script:

```bash
cd /data/andrew/dev/packages/sources/anixpkgs
./scripts/generate-local-ssl-certs.sh
```

This will auto-detect your LAN IP address and create:
- `~/secrets/vpn/rootCA.pem` - Root CA certificate (**install this on your phone**)
- `~/secrets/vpn/rootCA-key.pem` - Root CA private key (keep secret!)
- `~/secrets/vpn/chain.pem` - Server certificate
- `~/secrets/vpn/key.pem` - Server private key

You can also specify your server IP manually:
```bash
./scripts/generate-local-ssl-certs.sh 192.168.1.100
```

### 2. Install CA Certificate on Your Phone

To avoid SSL warnings, you **must** install the root CA certificate on your phone.

#### Android

1. Transfer `~/secrets/vpn/rootCA.pem` to your phone (via email, USB, etc.)
2. Open **Settings** → **Security** → **Encryption & credentials**
3. Tap **Install a certificate** → **CA certificate**
4. Select the `rootCA.pem` file
5. Give it a name like "ATS Local CA" or "[hostname] Local CA"

#### iPhone/iPad

1. Transfer `rootCA.pem` to your device (email or AirDrop)
2. Open the file - iOS will prompt to install a profile
3. Go to **Settings** → **General** → **VPN & Device Management**
4. Install the profile
5. Go to **Settings** → **General** → **About** → **Certificate Trust Settings**
6. Enable **full trust** for the certificate

### 3. Access Your Server

Once the CA is installed, you can access your server via HTTPS:

```
https://ats.local:443
```

Or use your server's IP address:
```
https://192.168.1.100:443
```

You can also use HTTP if you prefer:
```
http://ats.local:80
```

## Technical Details

### Certificate Validity

- The certificates are valid for **~825 days** (mkcert default)
- They're valid for:
  - `[hostname].local`
  - `*.[hostname].local` (wildcard for subdomains)
  - `localhost`
  - `127.0.0.1`
  - Your LAN IP address

### How It Works

1. **mkcert** creates a local CA (certificate authority)
2. The server certificate is signed by this CA
3. By installing the CA certificate on your phone, your phone trusts any certificate signed by that CA
4. This is the same mechanism used by commercial CAs like Let's Encrypt

### Nginx Configuration

The nginx server is configured to:
- Listen on port 80 (HTTP)
- Listen on port 443 (HTTPS with SSL)
- **NOT** redirect HTTP to HTTPS (both are supported)
- Run as user `andrew` with group `dev`

The SSL certificate files are stored in `~/secrets/vpn/`:
- `chain.pem` - Server certificate (readable by nginx)
- `key.pem` - Server private key (readable by nginx, mode 600)

### Backup with rcrsync

Since the certificates are in `~/secrets/`, they will be backed up by the `rcrsync` tool (if configured). This means:
- You don't lose your CA when backing up
- All your devices stay trusted after a restore
- You don't need to reinstall CA certificates on your devices after a restore

## Troubleshooting

### SSL Warning on Phone

If you see "Your connection is not private" or similar:
- Verify you installed the **CA certificate** (`rootCA.pem`), not the server certificate
- On iOS, ensure you enabled **full trust** in Certificate Trust Settings
- Try clearing Chrome's cache or restarting the browser

### Certificate Expired

If the certificate expires:
```bash
cd /data/andrew/dev/packages/sources/anixpkgs
./scripts/generate-local-ssl-certs.sh
```

The script will backup old certificates and create new ones.

### Connection Refused

- Verify the firewall allows ports 80 and 443:
  ```bash
  sudo iptables -L -n | grep -E '80|443'
  ```
- Check nginx is running:
  ```bash
  systemctl status nginx
  ```
- Verify the server services are running:
  ```bash
  systemctl status stampserver
  systemctl status rankserver
  ```

### Wrong IP Address

If your server's LAN IP changed:
```bash
./scripts/generate-local-ssl-certs.sh [new-ip-address]
```

## Security Notes

- **Private key security**: The `key.pem` and `rootCA-key.pem` files should be kept secret. They're stored in `~/secrets/` with restricted permissions.
- **CA installation**: Only install the CA certificate on devices you own and trust.
- **Local network only**: These certificates are only for local LAN access. They won't work over the internet.
- **Self-signed**: These are self-signed certificates. They provide encryption but not identity verification (unlike commercial CAs).

## File Permissions

The certificate files have the following permissions:
```
-rw-r--r-- chain.pem       (644) - Server certificate, readable by all
-rw------- key.pem          (600) - Server private key, readable only by owner
-rw-r--r-- rootCA.pem       (644) - CA certificate, readable by all
-rw------- rootCA-key.pem   (600) - CA private key, readable only by owner
```

Nginx runs as user `andrew` with group `dev`, so it can read all these files.
