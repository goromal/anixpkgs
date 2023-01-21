#!/bin/bash

set -e pipefail

nb() {
nix-build . -A $1
}

echo "Building ROS packages..."

nb rosPackages.noetic.std-msgs
nb rosPackages.noetic.geometry-msgs
nb rosPackages.noetic.message-generation
nb rosPackages.noetic.roscpp
nb rosPackages.noetic.rospy
nb rosPackages.noetic.nav-msgs
nb rosPackages.noetic.sensor-msgs
nb rosPackages.noetic.tf2
nb rosPackages.noetic.tf2-ros
nb rosPackages.noetic.visualization-msgs
nb rosPackages.noetic.eigen-conversions
nb rosPackages.noetic.message-runtime
nb rosPackages.noetic.dynamic-reconfigure
nb rosPackages.noetic.ublox-msgs
nb rosPackages.noetic.eigen-stl-containers
nb rosPackages.noetic.tf
nb rosPackages.noetic.std-srvs
nb rosPackages.noetic.gazebo
nb rosPackages.noetic.gazebo-plugins
nb rosPackages.noetic.gazebo-ros
nb rosPackages.noetic.ros-core

nb aerowake.acl_msgs
nb aerowake.air_dynamics
nb aerowake.boat_dynamics
nb aerowake.compass_driver
nb aerowake.flight
nb aerowake.groundstation
nb aerowake.mav_msgs
nb aerowake.mav_disturbance_observer
nb aerowake.params
nb aerowake.roscopter
nb aerowake.roscopter_msgs
nb aerowake.roscopter_utils
nb aerowake.rosflight
nb aerowake.rosflight_firmware
nb aerowake.rosflight_msgs
nb aerowake.rosflight_sim
nb aerowake.rosflight_utils
nb aerowake.rosflight_sil
nb aerowake.sim
nb aerowake.tether_dynamics
nb aerowake.uav_dynamics
nb aerowake.utils
nb aerowake.vision
