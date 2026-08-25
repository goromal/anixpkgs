# S4 Phase-1: omg160 confirmation variant of the INDI-on-JSON-backend gate.
#
# Identical to indi-drag-rejection-indi.nix (drag OFF, CC3_OUTER_EN=1, DDS
# traj_server, circle_slow + lemniscate_fast, CC3_G1_RP=500) EXCEPT the C1
# inner-loop angular-accel filter cutoff CC3_OMG_FILT is swept 80 -> 160.
#
# The shipped omg80 tune BUZZES on this real-lag backend under the OUTER_EN=1
# demo condition (Task 6: circle_slow track_rms ~10.5 m, saturation 7-13%). A
# standalone runtime sweep found omg160 clean AND still active, but only against
# a rate-command PROXY. This env confirms/refutes omg160 under the REAL
# OUTER_EN=1 + DDS Layer-B condition.
#
# Run: nix-build pkgs/nixos/sitl-envs/indi-drag-rejection-indi-omg160.nix
import ./indi-drag-rejection-indi.nix { omgFilt = 160; }
