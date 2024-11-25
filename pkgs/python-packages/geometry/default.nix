{ callPackage, clangStdenv, cmake, manif-geom-cpp, eigen, numpy, pybind11
, python, pythonOlder, pytestCheckHook, buildPythonPackage, pkg-src }:
callPackage ../pythonPkgFromPybind.nix {
  pname = "geometry";
  version = "1.0.0";
  description = "Implementations for SO(3) and SE(3).";
  inherit clangStdenv;
  inherit pkg-src;
  cppNativeBuildInputs = [ cmake ];
  cppBuildInputs = [ manif-geom-cpp eigen ];
  hasTests = true;
  inherit pybind11;
  inherit python;
  inherit pythonOlder;
  inherit pytestCheckHook;
  inherit buildPythonPackage;
  propagatedBuildInputs = [ ];
  checkPkgs = [ numpy ];
  longDescription = ''
    [Repository](https://github.com/goromal/geometry)

    Python-wrapped version of the C++ [manif-geom-cpp](../cpp/manif-geom-cpp.md) library.

    ## Example Usage

    Example usage of SO3:

    ```python
    # action
    q = SO3.random()
    v = np.random.random(3)
    qv1 = q * v
    qv2 = q.R().dot(v)
    assert np.allclose(qv1, qv2)

    # inversion and composition
    qI = SO3.identity()
    q1 = SO3.random()
    q1i = q1.inverse()
    q1I = q1 * q1i
    assert np.allclose(qI.array(), q1I.array())

    # Euler conversions
    roll = -1.2
    pitch = 0.6
    yaw = -0.4
    q = SO3.fromEuler(roll, pitch, yaw)
    rpy = q.toEuler()
    assert np.isclose(roll, rpy[0]) and np.isclose(pitch, rpy[1]) and np.isclose(yaw, rpy[2])

    # plus / minus
    R1 = SO3.random()
    w = np.array([0.5, 0.2, 0.1])
    R2 = R1 + w
    w2 = R2 - R1
    assert np.allclose(w, w2)

    # chart maps
    q = SO3.random()
    w = np.random.random(3)
    qlog = SO3.Log(q)
    q2 = SO3.Exp(qlog)
    assert np.allclose(q.array(), q2.array())
    wexp = SO3.Exp(w)
    w2 = SO3.Log(wexp)
    assert np.allclose(w, w2)

    # scaling
    qI = SO3.identity()
    qIs = 5.0 * qI
    assert np.allclose(qI.array(), qIs.array())
    qr = SO3.random()
    qr2 = qr * 0.2
    qr3 = qr2 / 0.2
    assert np.allclose(qr.array(), qr3.array())
    ```
  '';
}
