{
  runCommand,
  imagemagick,
  pkgData,
  screenResolution,
  label,
  forcedImage ? null,
  forcedIdx ? null,
}:
let
  minWpIdx = 1;
  maxWpIdx = 12;
  timestamp = builtins.currentTime;
  randomIntDrv = runCommand "random-int-${toString timestamp}" { inherit timestamp; } ''
    echo $((${builtins.toString minWpIdx} + RANDOM % ${builtins.toString maxWpIdx})) > $out
  '';
  randomInt =
    if forcedIdx != null then forcedIdx else builtins.fromJSON (builtins.readFile randomIntDrv);
  sourceImage =
    if forcedImage != null then
      forcedImage
    else
      pkgData.img.wallpapers."wallpaper${builtins.toString randomInt}".data;
  match = builtins.match "([0-9]+)x([0-9]+)" screenResolution;
  width = builtins.fromJSON (builtins.elemAt match 0);
  height = builtins.fromJSON (builtins.elemAt match 1);
  margin_buffer = 50;
  label_x = margin_buffer;
  label_y = height - margin_buffer;
  logo_w = 250;
  logo_h = 250;
  logo_x = width / 2 - logo_w / 2;
  logo_y = height / 2 - logo_h / 2;
  anix_w = 325;
  anix_h = 150;
  anix_x = width - anix_w;
  anix_y = height - anix_h;
in
runCommand "make-wallpaper-${builtins.toString randomInt}" { } ''
  ${imagemagick}/bin/magick -font ${pkgData.fonts.nexa.data} -pointsize 30 -fill white \
    ${sourceImage} \
    -resize ${screenResolution}^ -gravity west -extent ${screenResolution} -gravity northwest \
    \( ${pkgData.img.ajt-logo-white.data} -resize ${builtins.toString logo_w}x${builtins.toString logo_h}! \) -geometry +${builtins.toString logo_x}+${builtins.toString logo_y} -composite \
    \( ${pkgData.img.anix-logo-white-bmp.data} -resize ${builtins.toString anix_w}x${builtins.toString anix_h}! \) -geometry +${builtins.toString anix_x}+${builtins.toString anix_y} -composite \
    -draw 'text ${builtins.toString label_x},${builtins.toString label_y} "${label}"' \
    $out
''
