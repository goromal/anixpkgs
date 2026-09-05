# Differential-flatness setpoint (NED world frame) for the S3 Layer-B INDI
# outer loop. Field order/types mirror the AP_DDS IDL
# (ardupilot/libraries/AP_DDS/Idl/ardupilot_msgs/msg/FlatSetpoint.idl) so the
# DDS wire type matches ardupilot_msgs::msg::dds_::FlatSetpoint_.
builtin_interfaces/Time stamp
geometry_msgs/Vector3 position
geometry_msgs/Vector3 velocity
geometry_msgs/Vector3 acceleration
geometry_msgs/Vector3 jerk
geometry_msgs/Vector3 snap
float64 yaw
float64 yaw_rate
float64 yaw_accel
