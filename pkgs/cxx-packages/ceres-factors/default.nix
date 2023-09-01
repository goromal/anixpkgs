{ clangStdenv, cmake, eigen, ceres-solver, manif-geom-cpp, boost, pkg-src }:
clangStdenv.mkDerivation {
  name = "ceres-factors";
  version = "1.0.0";
  src = pkg-src;
  nativeBuildInputs = [ cmake ];
  buildInputs = [ eigen ceres-solver manif-geom-cpp boost ];
  preConfigure = ''
    cmakeFlags="$cmakeFlags --no-warn-unused-cli"
  '';
  meta = {
    description =
      "C++ library with custom parameterizations and cost functions for the Ceres Solver.";
    longDescription = ''
      [Repository](https://github.com/goromal/ceres-factors)

      Examples documented in the [unit tests](https://github.com/goromal/ceres-factors/tree/main/tests).

      Articles/tutorials showcasing some of the custom cost functions and parameterizations:

      - [Ceres Solver Python Tutorial (Linux)](https://notes.andrewtorgesen.com/doku.php?id=public:ceres)
      - [2D Range-Bearing Landmark Resolution with Ceres](https://notes.andrewtorgesen.com/doku.php?id=public:ceres-rangebearing)
    '';
  };
}
