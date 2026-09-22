# anix-upgrade

Upgrade the operating system and view the delta.  [NIXOS VERSION]


## Usage

```bash
usage: anix-upgrade [-v|--version VERSION;-c|--commit COMMIT;-b|--branch BRANCH;-s|--source SOURCETREE] [--local] [--boot]

Upgrade the operating system and view the delta.  [NIXOS VERSION]

The selected source tree declares its rebuild mode. Current trees use a flake configuration; older trees fall back to the legacy channel-based configuration.

On standalone Home Manager systems, current trees also supply the Home Manager
executable and Nixpkgs revision used for the switch. Existing Determinate Nix
installations are left in place. Older channel-based trees use the installed
`home-manager` command as a downgrade compatibility path.

```
