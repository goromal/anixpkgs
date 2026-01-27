{ writeShellScriptBin, imagemagick, pkgData, screenResolution, label }:
let
  minWpIdx = pkgData.img.wallpapers.minWallpaperIdx;
  maxWpIdx = pkgData.img.wallpapers.maxWallpaperIdx;

  script = writeShellScriptBin "wallpaper-regen" ''
    set -euo pipefail

    # Generate random wallpaper index
    RANDOM_IDX=$((${toString minWpIdx} + RANDOM % ${toString maxWpIdx}))

    # Determine source image based on random index
    case $RANDOM_IDX in
      ${builtins.concatStringsSep "\n" (builtins.genList (i:
        let idx = i + 1;
        in "  ${toString idx}) SOURCE_IMAGE=\"${
          pkgData.img.wallpapers."wallpaper${toString idx}".data
        }\" ;;") maxWpIdx)}
    esac

    # Parse screen resolution
    RESOLUTION="${screenResolution}"
    WIDTH=$(echo "$RESOLUTION" | cut -d'x' -f1)
    HEIGHT=$(echo "$RESOLUTION" | cut -d'x' -f2)

    # Calculate positions
    MARGIN_BUFFER=50
    LABEL_X=$MARGIN_BUFFER
    LABEL_Y=$((HEIGHT - MARGIN_BUFFER))
    LOGO_W=250
    LOGO_H=250
    LOGO_X=$((WIDTH / 2 - LOGO_W / 2))
    LOGO_Y=$((HEIGHT / 2 - LOGO_H / 2))
    ANIX_W=325
    ANIX_H=150
    ANIX_X=$((WIDTH - ANIX_W))
    ANIX_Y=$((HEIGHT - ANIX_H))

    # Output path
    OUTPUT="$HOME/.background-image"
    TEMP_OUTPUT="$OUTPUT.tmp"

    # Generate wallpaper
    ${imagemagick}/bin/magick -font ${pkgData.fonts.nexa.data} -pointsize 30 -fill white \
      "$SOURCE_IMAGE" \
      -resize "$RESOLUTION^" -gravity west -extent "$RESOLUTION" -gravity northwest \
      \( ${pkgData.img.ajt-logo-white.data} -resize ''${LOGO_W}x''${LOGO_H}! \) \
        -geometry +''${LOGO_X}+''${LOGO_Y} -composite \
      \( ${pkgData.img.anix-logo-white-bmp.data} -resize ''${ANIX_W}x''${ANIX_H}! \) \
        -geometry +''${ANIX_X}+''${ANIX_Y} -composite \
      -draw "text ''${LABEL_X},''${LABEL_Y} \"${label}\"" \
      "$TEMP_OUTPUT"

    # Atomically replace the wallpaper
    mv "$TEMP_OUTPUT" "$OUTPUT"

    echo "Wallpaper regenerated (index: $RANDOM_IDX)"
  '';
in script
