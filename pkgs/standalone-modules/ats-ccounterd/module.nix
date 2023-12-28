{ pkgs, config, lib, ... }:
with pkgs;
with lib;
let
  cfg = config.services.ats-ccounterd;
  counterScript = writeShellScript "ats-ccounterd" ''
    authm refresh --headless 1  || { >&2 echo "authm refresh error!"; exit 1; }
    lines="$(wiki-tools get --page-id calorie-journal | grep $(printf '%(%Y-%m-%d)T\n' -1))"
    if [[ -z $lines ]]; then
      exit
    fi
    ctotal=0
    clim=1950
    while IFS= read -r line; do
      c=`echo ''${line##* }`
      ctotal=$(( ctotal + c ))
    done <<< "$lines"
    echo $ctotal
    if (( ctotal <= clim )); then
      gmail-manager gbot-send 6612105214@vzwpix.com "ats-ccounterd" \
        "Calorie counter: $ctotal / $clim ✅"
      gmail-manager gbot-send andrew.torgesen@gmail.com "ats-ccounterd" \
        "Calorie counter: $ctotal / $clim ✅"
    else
      gmail-manager gbot-send 6612105214@vzwpix.com "ats-ccounterd" \
        "Calorie counter: $ctotal / $clim 🚨"
      gmail-manager gbot-send andrew.torgesen@gmail.com "ats-ccounterd" \
        "Calorie counter: $ctotal / $clim 🚨"
    fi
  '';
in {
  options.services.ats-ccounterd = with types; {
    enable = mkEnableOption "enable ATS ccounterd script";
    orchestratorPkg = mkOption {
      type = types.package;
      description = "The orchestrator package to use";
    };
  };

  config = mkIf cfg.enable {
    systemd.timers.ats-ccounterd = {
      wantedBy = [ "timers.target" ];
      after = [ "ats-greeting.service" ];
      timerConfig = {
        OnCalendar = [ "*-*-* 10:00:00" "*-*-* 14:00:00" "*-*-* 20:00:00" ];
        Unit = "ats-ccounterd.service";
      };
    };
    systemd.services.ats-ccounterd = {
      enable = true;
      description = "ATS ccounterd script";
      script =
        "${cfg.orchestratorPkg}/bin/orchestrator bash 'bash ${counterScript}'";
      serviceConfig = {
        Type = "oneshot";
        ReadWritePaths = [ "/data/andrew" ];
        User = "andrew";
        Group = "dev";
      };
    };
  };
}
