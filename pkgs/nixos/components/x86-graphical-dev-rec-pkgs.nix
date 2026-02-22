{
  pkgs,
  config,
  lib,
  ...
}:
with import ../dependencies.nix;
let
  cfg = config.mods.opts;
  # Wrap SuperCollider to use PipeWire's JACK libraries
  supercollider-pipewire = pkgs.symlinkJoin {
    name = "supercollider-pipewire";
    paths = [ pkgs.supercollider-with-sc3-plugins ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/sclang \
        --prefix LD_LIBRARY_PATH : ${pkgs.pipewire.jack}/lib
      wrapProgram $out/bin/scsynth \
        --prefix LD_LIBRARY_PATH : ${pkgs.pipewire.jack}/lib
    '';
  };
in
{
  home.packages = [
    # Tidal Cycles music environment (uses JACK via PipeWire compatibility)
    supercollider-pipewire
    pkgs.haskellPackages.tidal
    # SuperDirt installation script
    (pkgs.writeShellScriptBin "install-superdirt" ''
            echo "Installing SuperDirt quark..."
            INSTALL_SCRIPT=$(mktemp --suffix=.scd)
            cat > "$INSTALL_SCRIPT" << 'SCDEOF'
      // Install SuperDirt and dependencies
      Quarks.install("SuperDirt");
      "SuperDirt installation complete!".postln;
      0.exit;
      SCDEOF

            echo "Running SuperCollider to install SuperDirt..."
            echo "This may take a few minutes..."
            timeout 300 ${supercollider-pipewire}/bin/sclang "$INSTALL_SCRIPT" || {
              if [ $? -eq 124 ]; then
                echo ""
                echo "Installation timed out, but SuperDirt may have been installed successfully."
                echo "Check if SuperDirt directory exists:"
                ls -la ~/.local/share/SuperCollider/downloaded-quarks/SuperDirt 2>/dev/null && echo "SuperDirt is installed!" || echo "SuperDirt not found."
              fi
            }

            rm -f "$INSTALL_SCRIPT"
            echo ""
            echo "You can now start SuperCollider with: sclang"
    '')
    # Helper script to route SuperCollider audio to current default sink
    (pkgs.writeShellScriptBin "sc-route-audio" ''
      # Check if SuperCollider is running
      if ! ${pkgs.pipewire}/bin/pw-link -o | grep -q "SuperCollider:out_1"; then
        echo "SuperCollider (scsynth) is not running. Start SuperCollider first."
        exit 1
      fi

      # Get all available sinks with playback ports
      echo "Available audio outputs:"
      ${pkgs.pipewire}/bin/pw-link -i | grep "playback_FL" | sed 's/:playback_FL//' | nl

      # Find default sink by looking for bluez or alsa outputs
      BLUETOOTH_SINK=$(${pkgs.pipewire}/bin/pw-link -i | grep "bluez_output.*playback_FL" | sed 's/:playback_FL//' | head -1)
      BUILTIN_SINK=$(${pkgs.pipewire}/bin/pw-link -i | grep "alsa_output.*playback_FL" | sed 's/:playback_FL//' | head -1)

      # Prefer Bluetooth if available
      if [ -n "$BLUETOOTH_SINK" ]; then
        TARGET_SINK="$BLUETOOTH_SINK"
        echo ""
        echo "Using Bluetooth audio: $TARGET_SINK"
      elif [ -n "$BUILTIN_SINK" ]; then
        TARGET_SINK="$BUILTIN_SINK"
        echo ""
        echo "Using built-in audio: $TARGET_SINK"
      else
        echo "Could not find suitable audio sink"
        exit 1
      fi

      echo "Connecting SuperCollider to: $TARGET_SINK"

      # Add links to target sink (don't remove existing ones, PipeWire can handle multiple)
      ${pkgs.pipewire}/bin/pw-link SuperCollider:out_1 "$TARGET_SINK:playback_FL" 2>/dev/null || echo "Left channel already connected"
      ${pkgs.pipewire}/bin/pw-link SuperCollider:out_2 "$TARGET_SINK:playback_FR" 2>/dev/null || echo "Right channel already connected"

      echo ""
      echo "✓ SuperCollider audio routing configured"
      echo "Current connections:"
      ${pkgs.pipewire}/bin/pw-link -l | grep -A 2 "SuperCollider:out"
    '')
    # Helper script to download GitHub sample repositories
    (pkgs.writeShellScriptBin "tidal-download-samples" ''
      if [ $# -ne 2 ]; then
        echo "Usage: tidal-download-samples <github-user/repo> <sample-name>"
        echo "Example: tidal-download-samples eddyflux/crate crate"
        exit 1
      fi

      REPO="$1"
      NAME="$2"
      SAMPLES_DIR="$HOME/.local/share/SuperCollider/downloaded-samples"
      TARGET_DIR="$SAMPLES_DIR/$NAME"

      mkdir -p "$SAMPLES_DIR"

      if [ -d "$TARGET_DIR" ]; then
        echo "Sample pack '$NAME' already exists at $TARGET_DIR"
        echo "Remove it first if you want to re-download."
        exit 0
      fi

      echo "Downloading samples from github.com/$REPO..."
      ${pkgs.git}/bin/git clone "https://github.com/$REPO.git" "$TARGET_DIR"

      echo ""
      echo "Samples downloaded to: $TARGET_DIR"
      echo "Restart SuperCollider for the samples to be loaded."
    '')
  ];

  home.file = with anixpkgs.pkgData; {
    # Tidal Cycles boot configuration (JACK via PipeWire)
    ".config/SuperCollider/startup.scd".text = ''
      // SuperCollider will use JACK, which PipeWire provides compatibility for
      (
        // Tidal Cycles optimized settings
        Server.local.options.numBuffers = 1024 * 256;
        Server.local.options.memSize = 8192 * 32;
        Server.local.options.numWireBufs = 128;
        Server.local.options.maxNodes = 1024 * 32;
        Server.local.options.numOutputBusChannels = 2;
        Server.local.options.numInputBusChannels = 2;

        // Boot server and load SuperDirt
        s.waitForBoot {
          ~dirt = SuperDirt(2, s);

          // Load default samples
          ~dirt.loadSoundFiles;

          // Load custom samples from downloaded-samples directory
          ~customSamplesPath = PathName(Platform.userAppSupportDir +/+ "downloaded-samples").fullPath;
          if(PathName(~customSamplesPath).isFolder, {
            ("Loading custom samples from: " ++ ~customSamplesPath).postln;
            ~dirt.loadSoundFiles(~customSamplesPath +/+ "*");
          }, {
            "No custom samples directory found. Use 'tidal-download-samples' to add custom samples.".postln;
          });

          ~dirt.start(57120, 0 ! 12);
          "SuperDirt ready!".postln;
        };
      )
    '';

    # GHCi configuration for Tidal Cycles
    ".ghci".text = ''
      :set -XTemplateHaskell
      :set -XTemplateHaskellQuotes
      :set -XOverloadedStrings
      :module Sound.Tidal.Context

      import Sound.Tidal.Context
    '';
  };

  programs.vscode = {
    profiles.default = {
      userSettings = {
        # TidalCycles configuration
        "tidalcycles.ghciPath" = "${pkgs.haskellPackages.ghcWithPackages (p: with p; [ tidal tidal-link ])}/bin/ghci";
        "tidalcycles.useBootFileInCurrentDirectory" = false;
        "files.associations" = {
          "*.tidal" = "haskell";
        };
      };
      extensions =
        with unstable.vscode-extensions;
        [
          justusadam.language-haskell # For .tidal file syntax highlighting
        ]
        ++ unstable.vscode-utils.extensionsFromVscodeMarketplace [
          {
            name = "vscode-tidalcycles";
            publisher = "tidalcycles";
            version = "2.0.2";
            sha256 = "sha256-TfRLJZcMpoBJuXitbRmacbglJABZrMGtSNXAbjSfLaQ=";
          }
        ];
    };
  };
}
