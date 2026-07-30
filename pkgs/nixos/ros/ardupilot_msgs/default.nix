# ardupilot_msgs: custom ROS 2 interface package built with the nix-ros-overlay
# jazzy set (we cannot modify the overlay, so this lives in anixpkgs and is
# built via ros-pkgs.rosPackages.jazzy.callPackage). Provides the S3 Layer-B
# FlatSetpoint message consumed by the in-firmware INDI outer loop over AP_DDS.
{ lib
, buildRosPackage
, ament-cmake
, builtin-interfaces
, geometry-msgs
, rosidl-default-generators
, rosidl-default-runtime
}:
buildRosPackage {
  pname = "ros-jazzy-ardupilot-msgs";
  version = "0.0.1";

  src = lib.cleanSourceWith {
    src = ./.;
    # keep only the ament package tree (drop this nix file from the src)
    filter = path: type:
      let base = baseNameOf path; in base != "default.nix";
  };

  buildType = "ament_cmake";
  buildInputs = [ ament-cmake rosidl-default-generators ];
  propagatedBuildInputs = [ builtin-interfaces geometry-msgs rosidl-default-runtime ];
  nativeBuildInputs = [ ament-cmake ];

  meta = {
    description = "ArduPilot custom ROS 2 messages (S3 Layer-B FlatSetpoint)";
    license = with lib.licenses; [ gpl3Plus ];
  };
}
