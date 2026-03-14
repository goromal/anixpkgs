{
  lib,
  writeShellScriptBin,
  mkcert,
  coreutils,
  iproute2,
}:
writeShellScriptBin "generate-local-ssl-certs" ''
  #
  # Generate self-signed SSL certificates for local LAN HTTPS access
  #
  # This script creates:
  # 1. A root CA certificate (rootCA.pem) - INSTALL THIS ON YOUR PHONE
  # 2. A server certificate signed by the CA (chain.pem + key.pem)
  #
  # Usage:
  #   generate-local-ssl-certs [server-ip]
  #
  # If server-ip is not provided, it will be auto-detected from the LAN interface.
  #

  set -euo pipefail

  CERT_DIR="''${HOME}/secrets/vpn"
  HOSTNAME=$(${coreutils}/bin/hostname)
  SERVER_IP="''${1:-}"

  # Auto-detect LAN IP if not provided
  if [[ -z "$SERVER_IP" ]]; then
      echo "Auto-detecting LAN IP address..."
      # Get the IP address of the primary LAN interface (not loopback)
      SERVER_IP=$(${iproute2}/bin/ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v '^127\.' | head -1)
      if [[ -z "$SERVER_IP" ]]; then
          echo "ERROR: Could not auto-detect LAN IP. Please provide it as an argument."
          echo "Usage: $0 [server-ip]"
          exit 1
      fi
      echo "Detected LAN IP: $SERVER_IP"
  fi

  echo "Generating SSL certificates for local HTTPS..."
  echo "Hostname: ''${HOSTNAME}.local"
  echo "IP Address: ''${SERVER_IP}"
  echo "Certificate directory: ''${CERT_DIR}"
  echo

  # Create cert directory if it doesn't exist
  ${coreutils}/bin/mkdir -p "''${CERT_DIR}"
  cd "''${CERT_DIR}"

  # Backup existing certs if they exist
  if [[ -f rootCA.pem ]] || [[ -f chain.pem ]] || [[ -f key.pem ]]; then
      BACKUP_DIR="backup-$(${coreutils}/bin/date +%Y%m%d-%H%M%S)"
      echo "Backing up existing certificates to ''${BACKUP_DIR}..."
      ${coreutils}/bin/mkdir -p "''${BACKUP_DIR}"
      [[ -f rootCA.pem ]] && ${coreutils}/bin/mv rootCA.pem "''${BACKUP_DIR}/"
      [[ -f rootCA-key.pem ]] && ${coreutils}/bin/mv rootCA-key.pem "''${BACKUP_DIR}/"
      [[ -f chain.pem ]] && ${coreutils}/bin/mv chain.pem "''${BACKUP_DIR}/"
      [[ -f key.pem ]] && ${coreutils}/bin/mv key.pem "''${BACKUP_DIR}/"
      echo "Backup complete."
      echo
  fi

  echo "Step 1: Creating root CA..."
  # Create a new CA
  export CAROOT="''${CERT_DIR}"
  ${mkcert}/bin/mkcert -install

  echo
  echo "Step 2: Generating server certificate..."
  # Generate server certificate with multiple SANs (Subject Alternative Names)
  ${mkcert}/bin/mkcert \
      -cert-file chain.pem \
      -key-file key.pem \
      "''${HOSTNAME}.local" \
      "*.''${HOSTNAME}.local" \
      localhost \
      127.0.0.1 \
      "''${SERVER_IP}"

  # Set proper permissions
  ${coreutils}/bin/chmod 644 chain.pem
  ${coreutils}/bin/chmod 600 key.pem
  ${coreutils}/bin/chmod 644 rootCA.pem
  ${coreutils}/bin/chmod 600 rootCA-key.pem

  echo
  echo "================================================================================"
  echo "SSL Certificate Generation Complete!"
  echo "================================================================================"
  echo
  echo "Server certificates created:"
  echo "  - Certificate: ''${CERT_DIR}/chain.pem"
  echo "  - Private Key: ''${CERT_DIR}/key.pem"
  echo
  echo "Root CA certificate (for client devices):"
  echo "  - CA Certificate: ''${CERT_DIR}/rootCA.pem"
  echo "  - CA Private Key: ''${CERT_DIR}/rootCA-key.pem (keep this secret!)"
  echo
  echo "--------------------------------------------------------------------------------"
  echo "IMPORTANT: INSTALL THE CA CERTIFICATE ON YOUR PHONE"
  echo "--------------------------------------------------------------------------------"
  echo
  echo "To access your server via HTTPS from your phone, you MUST install the"
  echo "root CA certificate (rootCA.pem) on your phone. Otherwise, you'll get"
  echo "SSL certificate warnings."
  echo
  echo "For Android:"
  echo "  1. Transfer ''${CERT_DIR}/rootCA.pem to your phone"
  echo "  2. Go to Settings > Security > Encryption & credentials > Install a certificate"
  echo "  3. Select 'CA certificate' and choose the rootCA.pem file"
  echo "  4. Give it a name like \"''${HOSTNAME} Local CA\""
  echo
  echo "For iPhone/iPad:"
  echo "  1. Email rootCA.pem to yourself or transfer via AirDrop"
  echo "  2. Open the file on your device"
  echo "  3. Go to Settings > General > VPN & Device Management"
  echo "  4. Install the profile"
  echo "  5. Go to Settings > General > About > Certificate Trust Settings"
  echo "  6. Enable full trust for the certificate"
  echo
  echo "For Chrome/Chromium on Android:"
  echo "  - After installing the CA certificate system-wide (steps above),"
  echo "    Chrome should automatically trust it."
  echo
  echo "--------------------------------------------------------------------------------"
  echo "Your server URLs:"
  echo "  - HTTPS: https://''${HOSTNAME}.local:443"
  echo "  - HTTPS: https://''${SERVER_IP}:443"
  echo "  - HTTP:  http://''${HOSTNAME}.local:80"
  echo "  - HTTP:  http://''${SERVER_IP}:80"
  echo "--------------------------------------------------------------------------------"
  echo
  echo "Certificate valid for:"
  echo "  - ''${HOSTNAME}.local"
  echo "  - *.''${HOSTNAME}.local"
  echo "  - localhost"
  echo "  - 127.0.0.1"
  echo "  - ''${SERVER_IP}"
  echo
  echo "Note: The certificates will expire in ~825 days (mkcert default)."
  echo "      You can regenerate them anytime by running this script again."
  echo "================================================================================"
''
