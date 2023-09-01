{ callPackage, pytestCheckHook, buildPythonPackage, numpy, matplotlib, geometry
, pysignals, pkg-src }:
callPackage ../pythonPkgFromScript.nix {
  pname = "trafficsim";
  version = "1.0.0";
  description = "Simulate traffic.";
  script-file = "${pkg-src}/traffic.py";
  inherit pytestCheckHook buildPythonPackage;
  propagatedBuildInputs = [ numpy matplotlib geometry pysignals ];
  checkPkgs = [ ];
  longDescription = ''
    [Gist](https://gist.github.com/goromal/c37629235750b65b9d0ec0e17456ee96)

    Simple traffic simulator on a circular road. Cars have two control objectives: maintain a consistent distance between cars and maintain a consistent car speed.

    ```bash
    usage: trafficsim [-h] [--num_cars NUM_CARS] [--vel_des VEL_DES] [--vel_max VEL_MAX] [--beta_mu BETA_MU]
                    [--beta_sigma BETA_SIGMA] [--gamma_mu GAMMA_MU] [--gamma_sigma GAMMA_SIGMA]
                    [--vel_col_thresh VEL_COL_THRESH] [--pos_col_thresh POS_COL_THRESH]

    Simple traffic simulator on a circular road.

    optional arguments:
    -h, --help            show this help message and exit
    --num_cars NUM_CARS   Number of cars to simulate. (default: 7)
    --vel_des VEL_DES     Desired car velocity. (default: 1.0)
    --vel_max VEL_MAX     Maximum allowed car velocity. (default: 1.5)
    --beta_mu BETA_MU     Mean proportional gain. (default: 0.5)
    --beta_sigma BETA_SIGMA
                            Proportional gain standard deviation. (default: 0.5)
    --gamma_mu GAMMA_MU   Mean derivative gain. (default: 0.5)
    --gamma_sigma GAMMA_SIGMA
                            Derivative gain standard deviation. (default: 0.5)
    --vel_col_thresh VEL_COL_THRESH
                            Distance threshold for slowing down. (default: 0.3)
    --pos_col_thresh POS_COL_THRESH
                            Distance threshold for collision avoidance (default: 0.15)
    ```
  '';
}
