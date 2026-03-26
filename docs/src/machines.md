# Machine Management

***These notes are still a work-in-progress and are currently largely for my personal use only.***

## Home-Manager Example

1. Install Nix standalone:
```bash
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
```
3. Set proper Nix settings in `/etc/nix/nix.conf`:
```
substituters = https://cache.nixos.org/ https://github-public.cachix.org
trusted-public-keys = cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY= github-public.cachix.org-1:xofQDaQZRkCqt+4FMyXS5D6RNenGcWwnpAXRXJ2Y5kc=
narinfo-cache-positive-ttl = 0
narinfo-cache-negative-ttl = 0
experimental-features = nix-command flakes auto-allocate-uids
```
4. Add these Nix channels via `nix-channel --add URL NAME`:
```bash
$ nix-channel --list
home-manager https://github.com/nix-community/home-manager/archive/release-25.11.tar.gz
nixpkgs https://nixos.org/channels/nixos-25.11
```
5. Install home-manager: https://nix-community.github.io/home-manager/index.xhtml#sec-install-standalone

Example `home.nix` file for personal use:

```nix
{ config, pkgs, lib, ... }:
let
  user = "andrew";
  homedir = "/home/${user}";
  anixsrc = ./path/to/sources/anixpkgs/.;
in with import ../dependencies.nix; {
  home.username = user;
  home.homeDirectory = homedir;
  programs.home-manager.enable = true;

  imports = [
    "${anixsrc}/pkgs/nixos/components/opts.nix"
    "${anixsrc}/pkgs/nixos/components/base-pkgs.nix"
    "${anixsrc}/pkgs/nixos/components/base-dev-pkgs.nix"
    "${anixsrc}/pkgs/nixos/components/x86-rec-pkgs.nix"
    "${anixsrc}/pkgs/nixos/components/x86-graphical-pkgs.nix"
    "${anixsrc}/pkgs/nixos/components/x86-graphical-dev-pkgs.nix"
    "${anixsrc}/pkgs/nixos/components/x86-graphical-rec-pkgs.nix"
  ];

  mods.opts.standalone = true;
  mods.opts.homeDir = homedir;
  mods.opts.homeState = "23.05";
  mods.opts.browserExec = "google-chrome-stable";
}

```

`*-rec-*` packages can be removed for non-recreational use.

Symlink to `~/.config/home-manager/home.nix`.

Corresponding `~/.bashrc`:

```bash
export NIX_PATH=$HOME/.nix-defexpr/channels:/nix/var/nix/profiles/per-user/root/channels${NIX_PATH:+:$NIX_PATH}
. "$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh"
export NIXPKGS_ALLOW_UNFREE=1
# alias code='codium'
# eval "$(direnv hook bash)"
```

## Personal Machine Installation Instructions

*Sources*

- https://nixos.wiki/wiki/NixOS_Installation_Guide
- https://alexherbo2.github.io/wiki/nixos/install-guide/

1. Build the installation ISO with `NIXPKGS_ALLOW_UNFREE=1 nix build .#nixosConfigurations.installer-personal.config.system.build.isoImage`
2. Plug in a USB stick large enough to accommodate the image.
3. Find the right device with `lsblk` or `fdisk -l`. Replace `/dev/sdX` with the proper device (do not use `/dev/sdX1` or partitions of the disk; use the whole disk `/dev/sdX`).
4. Burn ISO to USB stick with `dd if=result/iso/[...]linux.iso of=/dev/sdX bs=4M status=progress conv=fdatasync`
5. On the new machine, one-time boot UEFI into the USB stick on the computer (will need to disable Secure Boot from BIOS first)
6. Login as the user `andrew`
7. Connect to the internet
8. Within the installer, run `sudo anix-install`
9. If everything went well, reboot
10. On the next reboot, login as user `andrew` again
11. Connect to the internet
12. Run `anix-init` 
13. Enjoy!

## JetPack Machine Installation Instructions

1. Ensure that the device has UEFI firmware installed. See https://github.com/anduril/jetpack-nixos.
2. Build the installation ISO with `nix build .#nixosConfigurations.installer-jetpack.config.system.build.isoImage`
3. Plug in a USB stick large enough to accommodate the image.
4. Find the right device with `lsblk` or `fdisk -l`. Replace `/dev/sdX` with the proper device (do not use `/dev/sdX1` or partitions of the disk; use the whole disk `/dev/sdX`).
5. Burn ISO to USB stick with `dd if=result/iso/[...]linux.iso of=/dev/sdX bs=4M status=progress conv=fdatasync`
6. Insert the USB drive into the Jetson device. On the AGX devkits, I've had the best luck plugging into the USB-C slot above the power barrel jack. You may need to try a few USB options until you find one that works with both the UEFI firmware and the Linux kernel.
7. Press power / reset as needed. When prompted, press ESC to enter the UEFI firmware menu. In the "Boot Manager", select the correct USB device and boot directly into it.
8. Connect to the internet
9. Within the installer, run `sudo anix-install`
10. If everything went well, reboot
11. On the next reboot, login as user `andrew` again
12. Connect to the internet
13. Run `anix-init` 
14. Enjoy!

## Upgrading NixOS versions with `anixpkgs`

Aside from the source code changes in `anixpkgs`, ensure that your channels have been updated **for the root user**:

```bash
# e.g., upgrading to 25.11:
home-manager https://github.com/nix-community/home-manager/archive/release-25.11.tar.gz
nixos https://nixos.org/channels/nixos-25.11
nixpkgs https://nixos.org/channels/nixos-25.11
```

`sudo nix-channel --update`. Then upgrade with

```bash
anix-upgrade [source specification] --local --boot
```

## Build a JetPack Installer ISO

Cross-compiled from x86_64. Requires `binfmt` support for aarch64 (enabled by default on NixOS with `boot.binfmt.emulatedSystems`).

```bash
nix build .#nixosConfigurations.installer-jetpack.config.system.build.isoImage
```

```bash
dd if=result/iso/[...]linux.iso of=/dev/sdX bs=4M status=progress conv=fdatasync
```

## Build a NixOS ISO Image

***TODO (untested)***; work out hardware configuration portion.

```bash
nixos-generate -f iso -c /path/to/personal/configuration.nix [-I nixpkgs=/path/to/alternative/nixpkgs]
```

```bash
sudo dd if=/path/to/nixos.iso of=/dev/sdX bs=4M conv=fsync status=progress
```

## Local SSL Setup for HTTPS Access

For machines configured with `runWebServer = true` (like ATS), you can enable HTTPS access from devices on your local network (especially phones) to avoid browser security warnings.

### Quick Start

1. **Generate SSL certificates** on the server:
   ```bash
   generate-local-ssl-certs
   ```

   The script will auto-detect your LAN IP address and create certificates in `~/secrets/vpn/`.

   If you need to specify a different IP address:
   ```bash
   generate-local-ssl-certs 192.168.1.100
   ```

2. **Install the CA certificate on your client devices**:

   Transfer `~/secrets/vpn/rootCA.pem` to your phone and install it:

   **Android:**
   - Settings → Security → Encryption & credentials → Install a certificate
   - Choose "CA certificate" and select `rootCA.pem`
   - Give it a name like "ATS Local CA"

   **iPhone/iPad:**
   - Email or AirDrop `rootCA.pem` to your device
   - Open the file to install the profile
   - Settings → General → VPN & Device Management → Install the profile
   - Settings → General → About → Certificate Trust Settings → Enable full trust

3. **Access your server via HTTPS**:
   ```
   https://ats.local:443
   ```

   Or use HTTP if you prefer (no automatic redirect):
   ```
   http://ats.local:80
   ```

### How It Works

- The nginx server listens on **both** HTTP (port 80) and HTTPS (port 443)
- There is **no automatic redirect** from HTTP to HTTPS - both protocols are supported
- The certificates are valid for:
  - `[hostname].local` (e.g., `ats.local`)
  - `*.[hostname].local` (wildcard for subdomains)
  - `localhost`, `127.0.0.1`, and your LAN IP address
- Certificates are stored in `~/secrets/vpn/` and backed up by `rcrsync`
- Certificates expire after ~825 days and can be regenerated anytime

### Regenerating Certificates

If your server IP changes or certificates expire:
```bash
generate-local-ssl-certs [new-ip-address]
```

The script will backup old certificates and create new ones. You won't need to reinstall the CA on your devices if you're replacing server certificates signed by the same CA.

### Troubleshooting

**SSL warnings still appear:**
- Verify you installed `rootCA.pem` (the CA certificate), not `chain.pem`
- On iOS, ensure you enabled full trust in Certificate Trust Settings
- Try clearing browser cache or restarting the browser

**Connection refused:**
- Check firewall allows ports 80 and 443: `sudo iptables -L -n | grep -E '80|443'`
- Verify nginx is running: `systemctl status nginx`

See [Local SSL Setup](./local-ssl-setup.md) for complete documentation.

## Vikunja Task Management (ATS Only)

ATS machines automatically include [Vikunja](https://vikunja.io/), an open-source task management system designed for collaboration between you and Claude Code.

### Accessing Vikunja

Once your ATS machine is running, Vikunja is accessible at:
- **Web UI (HTTPS)**: `https://ats.local:3457/`
- **Web UI (HTTP)**: `http://ats.local:3457/`
- **API**: `https://ats.local/vikunja/api/v1/` or `http://ats.local/vikunja/api/v1/`

The web UI is mobile-friendly and served through nginx on port 3457 with both HTTP and HTTPS support. The API is accessible at `/vikunja/` on the default ports (80/443) due to how the frontend is built in nixpkgs.

**Note**: For HTTPS access to work without certificate warnings, you need to install the SSL certificate on your client devices. See the [Local SSL Setup](#local-ssl-setup-for-https-access) section above.

### Initial Setup

1. **Create your first user** (registration is disabled after first use for security):
   ```bash
   # Open https://ats.local:3457/ in a browser and register
   # After registration, the service will reject new registrations
   ```

2. **Get your API token** for MCP integration:
   - Log in to Vikunja
   - Go to Settings → API Tokens
   - Create a new token and save it securely

3. **Configure Claude Code MCP** (see [MCP Integration](#mcp-integration) section below)

### Using Vikunja with Claude Code

Once you've configured the MCP integration (see below), Claude Code can directly interact with your Vikunja tasks during conversations.

#### Typical Workflow

**You (via Web/Phone)**:
1. Open `https://ats.local:3457/` on your device
2. Create projects for different areas (e.g., "Development", "Personal", "Research")
3. Create tasks with descriptions, priorities, and due dates
4. Review and comment on tasks Claude has worked on

**Claude Code (via MCP)**:
1. Lists your tasks when you start a conversation: "What should I work on?"
2. Creates subtasks as it breaks down complex work
3. Updates task status and adds progress comments
4. Marks tasks complete when finished
5. Creates new tasks for follow-up work or issues discovered

#### Example Interactions

- **You**: "What tasks do I have in the Development project?"
  - Claude lists all tasks with their status, priority, and descriptions

- **You**: "Work on task 42"
  - Claude reads the task details and gets to work
  - Creates subtasks for each step
  - Adds comments with progress updates
  - Marks task complete when done

- **You**: "Create a task to implement user authentication with JWT"
  - Claude creates the task with a detailed description
  - Can immediately start working on it if requested

### MCP Integration

The Vikunja MCP server (`vikunja-mcp-server`) is automatically installed on ATS machines and provides direct integration between Claude Code and Vikunja.

#### Getting Your API Token

1. Log in to Vikunja at `https://ats.local:3457/`
2. Go to Settings → API Tokens
3. Click "Create new token"
4. Copy the generated token (you won't be able to see it again!)

#### Configuring Claude Code

**Option 1: Automatic Configuration (Recommended)**

The easiest way is to store your API token in `~/secrets/vikunja/secrets.json` on the ATS machine:

```json
{
  "token": "your-api-token-here"
}
```

After adding the token, rebuild your system configuration:
```bash
sudo nixos-rebuild switch
```

The MCP server will be automatically registered using `claude mcp add` and stored in `~/.claude.json`.

**Option 2: Manual Configuration**

If you prefer manual configuration, use the Claude Code MCP CLI:

```bash
claude mcp add -s user \
  -e VIKUNJA_URL=https://ats.local:3457 \
  -e VIKUNJA_API_TOKEN=your-token-here \
  -- vikunja /run/current-system/sw/bin/vikunja-mcp-server
```

To verify it's registered:
```bash
claude mcp list
```

**Configuration Options**

You can customize the MCP integration in your NixOS configuration:

```nix
services.vikunja-ats.mcp = {
  enable = true;  # Default: true
  secretsFile = "/custom/path/secrets.json";  # Default: ~/secrets/vikunja/secrets.json
  tokenKey = "custom_key";  # Default: "token"
  configFile = "/custom/path/.claude.json";  # Default: ~/.claude.json (not used directly, but tracked)
};
```

**Note**: Use HTTPS (`https://ats.local:3457`) for the URL to ensure secure API access.

#### Available MCP Tools

Once configured, Claude Code has native access to these Vikunja tools:
- `vikunja_list_projects`, `vikunja_get_project` - Browse and view projects
- `vikunja_list_tasks`, `vikunja_get_task` - View tasks
- `vikunja_create_task` - Create new tasks
- `vikunja_update_task` - Update task fields (title, description, priority, etc.)
- `vikunja_complete_task` - Mark tasks as done
- `vikunja_add_comment`, `vikunja_get_comments` - Add and view task comments

#### Usage Examples

With the MCP server configured, you can interact with Vikunja directly in Claude Code:

- "What tasks do I have in the Development project?"
- "Create a task in project 5 to implement user authentication"
- "Add a comment to task 42 with the latest progress"
- "Mark task 15 as complete"
- "Update task 23's priority to high"

### Data Location

- **Database**: `/var/lib/vikunja/vikunja.db` (SQLite)
- **Files**: `/var/lib/vikunja/files/`
- **Logs**: `/var/lib/vikunja/logs/`
- **Configuration**: `/etc/vikunja/config.yml`

### Backup

The Vikunja database is automatically backed up daily at midnight by the `ats-vikunja-backup` orchestrator job:
- Copies `/var/lib/vikunja/vikunja.db` to `~/data/vikunja/vikunja.db`
- Syncs to cloud storage via `rcrsync override data vikunja`

You can manually trigger a backup with:

```bash
ssh andrew@ats.local
sudo systemctl start ats-vikunja-backup.service
```

Or manually copy the database:

```bash
ssh andrew@ats.local
sudo cp /var/lib/vikunja/vikunja.db ~/backups/vikunja-$(date +%Y%m%d).db
```

### Architecture

Vikunja is served through nginx as a reverse proxy with HTTPS support:
- Vikunja serves both the web UI and API from a single service on internal port 3456
- Frontend accessible at `https://ats.local:3457` (HTTPS) or `http://ats.local:3457` (HTTP)
- API accessible at `https://ats.local/vikunja/api/v1/` (HTTPS) or `http://ats.local/vikunja/api/v1/` (HTTP)
- Internal port: 3456 (centrally managed in `service-ports.nix`)
- External ports: 3457 (frontend with HTTPS/HTTP), 80/443 (API via `/vikunja/`)
- SSL certificates: Same self-signed certificates as main web server (`~/secrets/vpn/`)

The nixpkgs Vikunja frontend is built with `/vikunja/` as the hardcoded API base path, so we serve the frontend on port 3457 while also proxying `/vikunja/` on ports 80/443 for API access. Both HTTP and HTTPS are supported without forced redirects.

## Miscellaneous

### Cloud Syncing

The following mount points are recommended (using [rclone](https://rclone.org/) to set up):

- `dropbox:secrets` -> `rclone copy` -> `~/secrets`
- `dropbox:configs`-> `rclone copy` -> `~/configs`
- `dropbox:Games` -> `rclone copy` -> `~/games`
- `box:data` -> `rclone copy` -> `~/data`
- `box:.devrc` -> `rclone copy` -> `~/.devrc`
- `drive:Documents` -> `rclone copy` -> `~/Documents`

### Music with Tidal

If you haven't already, run:

```bash
install-superdirt
```

Open VSCode, run `sclang` in the terminal (close with `0.exit`), and open up a `.tidal` file and get to work.

Useful commands:

- Install samples with e.g., `tidal-download-samples eddyflux/crate crate`
- When `sclang` is running, associate with the correct audio device with `sc-route-audio`
