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
          ~dirt.loadSoundFiles;
          ~dirt.start(57120, 0 ! 12);
          "SuperDirt ready!".postln;
        };
      )
    '';
  };

  programs.vscode = {
    profiles.default = {
      userSettings = {
        # TidalCycles configuration
        "tidalcycles.ghciPath" = "${pkgs.haskellPackages.ghcWithPackages (p: [ p.tidal ])}/bin/ghci";
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
