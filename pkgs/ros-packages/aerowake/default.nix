{ rosDistro
, eigen
, libyamlcpp
, opencv
}:
with rosDistro;
let
    aerowakeSrc = builtins.fetchGit (import ./src.nix);
    version = "0.0.0";
    mkAerowakePkg = { pname, subdir, propagatedBuildInputs, postPatch ? "" }:
        buildRosPackage {
            inherit pname;
            inherit version;
            src = "${aerowakeSrc}/${subdir}";
            buildType = "catkin";
            nativeBuildInputs = [ catkin ];
            buildInputs = [ catkin cmake-modules roscpp rospy message-generation ];
            inherit propagatedBuildInputs;
            inherit postPatch;
        };
in rec {
    acl_msgs = mkAerowakePkg {
        pname = "acl-msgs";
        subdir = "acl_msgs";
        propagatedBuildInputs = [
            message-runtime
            std-msgs
            geometry-msgs
        ];
    };
    air_dynamics = mkAerowakePkg {
        pname = "air-dynamics";
        subdir = "air_dynamics";
        propagatedBuildInputs = [
            geometry-msgs
            visualization-msgs
            eigen
            rosflight_sil
            utils
        ];
    };
    boat_dynamics = mkAerowakePkg {
        pname = "boat-dynamics";
        subdir = "boat_dynamics";
        propagatedBuildInputs = [
            geometry-msgs
            visualization-msgs
            tf2
            tf2-ros
            eigen
            utils
        ];
    };
    compass_driver = mkAerowakePkg {
        pname = "aerowake-compass-driver";
        subdir = "compass_driver";
        propagatedBuildInputs = [
            utils
            geometry-msgs
            nav-msgs
            std-msgs
        ];
    };
    flight = mkAerowakePkg {
        pname = "aerowake-flight";
        subdir = "flight";
        propagatedBuildInputs = [
            rosflight_msgs
        ];
    };
    groundstation = mkAerowakePkg {
        pname = "aerowake-groundstation";
        subdir = "groundstation";
        propagatedBuildInputs = [
            geometry-msgs
            nav-msgs
            std-msgs
            flight
        ];
    };
    mav_msgs = mkAerowakePkg {
        pname = "mav-msgs";
        subdir = "mav_comm/mav_msgs";
        propagatedBuildInputs = [
            eigen
            geometry-msgs
            message-runtime
            std-msgs
            trajectory-msgs
        ];
    };
    mav_disturbance_observer = mkAerowakePkg {
        pname = "mav-disturbance-observer";
        subdir = "mav_disturbance_observer/unscented_kalman_filter";
        propagatedBuildInputs = [
            dynamic-reconfigure
            geometry-msgs
            mav_msgs
            nav-msgs
            sensor-msgs
            dynamic-reconfigure
            utils
            visualization-msgs
        ];
    };
    params = mkAerowakePkg {
        pname = "aerowake-params";
        subdir = "params";
        propagatedBuildInputs = [
            std-msgs
        ];
    };
    roscopter = mkAerowakePkg {
        pname = "aerowake-roscopter";
        subdir = "roscopter/roscopter";
        propagatedBuildInputs = [
            nav-msgs
            std-msgs
            sensor-msgs
            rosflight_msgs
            rosflight_utils
            eigen-conversions
            message-runtime
            dynamic-reconfigure
            roslib
            ublox-msgs
            roscopter_utils
            vision
        ];
    };
    roscopter_msgs = mkAerowakePkg {
        pname = "aerowake-roscopter-msgs";
        subdir = "roscopter/roscopter_msgs";
        propagatedBuildInputs = [
            message-runtime
        ];
    };
    roscopter_utils = mkAerowakePkg {
        pname = "aerowake-roscopter-utils";
        subdir = "roscopter/roscopter_utils";
        propagatedBuildInputs = [
            eigen
        ];
    };
    rosflight = mkAerowakePkg {
        pname = "aerowake-rosflight";
        subdir = "rosflight/rosflight";
        propagatedBuildInputs = [
            rosflight_msgs
            eigen-stl-containers
            geometry-msgs
            sensor-msgs
            std-msgs
            std-srvs
            tf
            eigen
            libyamlcpp
        ];
    };
    rosflight_firmware = mkAerowakePkg {
        pname = "aerowake-rosflight-firmware";
        subdir = "rosflight/rosflight_firmware";
        propagatedBuildInputs = [];
        postPatch = ''
            substituteInPlace firmware/src/param.cpp --replace GIT_VERSION_HASH "deadc0de"
        '';
    };
    rosflight_msgs = mkAerowakePkg {
        pname = "aerowake-rosflight-msgs";
        subdir = "rosflight/rosflight_msgs";
        propagatedBuildInputs = [
            std-msgs
            geometry-msgs
        ];
    };
    rosflight_sim = mkAerowakePkg {
        pname = "aerowake-rosflight-sim";
        subdir = "rosflight/rosflight_sim";
        propagatedBuildInputs = [
            eigen
            gazebo
            gazebo-plugins
            gazebo-ros
            geometry-msgs
            rosflight_firmware
            rosflight_msgs
        ];
    };
    rosflight_utils = mkAerowakePkg {
        pname = "aerowake-rosflight-utils";
        subdir = "rosflight/rosflight_utils";
        propagatedBuildInputs = [
            gazebo-msgs
            geometry-msgs
            rosflight_msgs
            rosflight_sim
            rosflight_firmware
            rosflight
            rosbag
            rosgraph-msgs
            sensor-msgs
            std-srvs
            visualization-msgs
        ];
    };
    rosflight_sil = mkAerowakePkg {
        pname = "aerowake-rosflight-sil";
        subdir = "rosflight_sil";
        propagatedBuildInputs = [
            eigen
            geometry-msgs
            nav-msgs
            rosflight_firmware
            rosflight_msgs
            utils
            message-runtime
        ];
    };
    sim = mkAerowakePkg {
        pname = "aerowake-sim";
        subdir = "sim";
        propagatedBuildInputs = [
            roscopter_msgs
            rosflight_msgs
            std-msgs
        ];
    };
    tether_dynamics = mkAerowakePkg {
        pname = "tether-dynamics";
        subdir = "tether_dynamics";
        propagatedBuildInputs = [
            tf2
            tf2-ros
            geometry-msgs
            visualization-msgs
            eigen
            rosflight_sil
            utils
        ];
    };
    uav_dynamics = mkAerowakePkg {
        pname = "uav-dynamics";
        subdir = "uav_dynamics";
        propagatedBuildInputs = [
            eigen
            geometry-msgs
            visualization-msgs
            rosflight_sil
            tf2
            tf2-ros
            utils
        ];
    };
    utils = mkAerowakePkg {
        pname = "aerowake-utils";
        subdir = "utils";
        propagatedBuildInputs = [
            eigen
            libyamlcpp
            geometry-msgs
            nav-msgs
            rosflight_msgs
            sensor-msgs
            std-msgs
            ublox-msgs
        ];
    };
    vision = mkAerowakePkg {
        pname = "aerowake-vision";
        subdir = "vision";
        propagatedBuildInputs = [
            cv-bridge
            geometry-msgs
            sensor-msgs
            std-msgs
            eigen
            utils
            visualization-msgs
            tf2
            tf2-ros
            opencv
            message-runtime
        ];
    };
}
