{ pkgs, config, lib, ... }:
with import ../dependencies.nix { inherit config; }; {
  home.packages = [
    anixpkgs.fqt
    anixpkgs.mfn
    anixpkgs.providence
    anixpkgs.providence-tasker

  ];

  home.file = with anixpkgs.pkgData; {

    "models/gender/${models.gender.proto.name}".source =
      models.gender.proto.data;
    "models/gender/${models.gender.weights.name}".source =
      models.gender.weights.data;
    "spleeter/pretrained_models/2stems/${models.spleeter.checkpoint.name}".source =
      models.spleeter.checkpoint.data;
    "spleeter/pretrained_models/2stems/${models.spleeter.model-data.name}".source =
      models.spleeter.model-data.data;
    "spleeter/pretrained_models/2stems/${models.spleeter.model-index.name}".source =
      models.spleeter.model-index.data;
    "spleeter/pretrained_models/2stems/${models.spleeter.model-meta.name}".source =
      models.spleeter.model-meta.data;

  };
}
