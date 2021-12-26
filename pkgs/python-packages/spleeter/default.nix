# https://github.com/deezer/spleeter
{ buildPythonPackage
, callPackage
, fetchPypi
, isPyPy
, pythonOlder
, python
, stdenv
, lib
, pytestCheckHook
, pytest-xdist
, shellingham
, coverage
, mypy
, black
, isort
, locale
, pandas
, tensorflow
, ffmpeg
, libsndfile
, llvm
, enum34
, isPy3k
, ffmpeg-python
, norbert
, gfortran
, pytest
, blas
, lapack
, writeTextFile
, cython
, setuptoolsBuildHook
, scipy
, tensorflow-tensorboard
, tensorflow-estimator
, h5py
, opt-einsum
, keras
, keras-preprocessing
, pillow
}:
let 
    numpy_1_16_6 = callPackage ./overrides/numpy_1_17_5.nix { # TODO
        inherit lib fetchPypi python buildPythonPackage gfortran pytest blas;
        inherit lapack writeTextFile isPyPy cython setuptoolsBuildHook;
    };
    sp_patched = scipy.override { numpy = numpy_1_16_6; };
    tftb_patched = tensorflow-tensorboard.override { numpy = numpy_1_16_6; };
    tfes_patched = tensorflow-estimator.override { numpy = numpy_1_16_6; };
    h5_patched = h5py.override { numpy = numpy_1_16_6; };
    oe_patched = opt-einsum.override { numpy = numpy_1_16_6; };
    pl_patched = pillow.override { numpy = numpy_1_16_6; };
    kp_patched = keras-preprocessing.override {
        numpy = numpy_1_16_6;
        pillow = pl_patched;
        scipy = sp_patched;
        # keras ????
    };
    kr_patched = keras.override {
        numpy = numpy_1_16_6;
        scipy = sp_patched;
        h5py = h5_patched;
        keras-preprocessing = kp_patched;
    };

    tf_patched = tensorflow.override { 
        numpy = numpy_1_16_6; 
        tensorflow-tensorboard = tftb_patched;
        tensorflow-estimator = tfes_patched;
        h5py = h5_patched;
        opt-einsum = oe_patched;
        keras = kr_patched;
        keras-preprocessing = kp_patched;
    };
    pd_patched = pandas.override { numpy = numpy_1_16_6; };
    nb_patched = norbert.override { scipy = sp_patched; };
    llvm-lite_0_36_0 = callPackage ./overrides/llvm-lite_0_36_0.nix {
        inherit lib stdenv fetchPypi buildPythonPackage python llvm pythonOlder;
        inherit isPyPy enum34 isPy3k;
    };
    click_7_1_2 = callPackage ./overrides/click_7_1_2.nix {
        inherit lib buildPythonPackage fetchPypi locale pytestCheckHook;
    };
    typer_0_3_2 = callPackage ./overrides/typer_0_3_2.nix {
        inherit lib stdenv buildPythonPackage fetchPypi black isort;
        click = click_7_1_2;
        inherit pytestCheckHook pytest-xdist shellingham coverage mypy;
    };
in buildPythonPackage rec {
    pname = "spleeter";
    version = "2.3.0";
    nativeBuildInputs = [
        ffmpeg
        libsndfile
    ];
    # Spleeter specifies >= 3.6, but flake8 tests fail on 3.7,
    # and I don't want to deal with that currently.
    disabled = pythonOlder "3.8";
    propagatedBuildInputs = [
        numpy_1_16_6
        pd_patched
        typer_0_3_2
        tf_patched
        llvm-lite_0_36_0
        ffmpeg-python
        nb_patched
    ];
    postPatch = ''
        substituteInPlace pyproject.toml --replace 'tensorflow = "2.5.0"' 'tensorflow = "2.7.0"'
        substituteInPlace setup.py --replace 'tensorflow==2.5.0' 'tensorflow==2.7.0'
        substituteInPlace PKG-INFO --replace 'tensorflow (==2.5.0)' 'tensorflow (==2.7.0)'
    '';
    src = fetchPypi {
        inherit pname version;
        sha256 = "b8b07a021c9b600c1e8aec73e5ff3fd4cce01b493f0661e77e2195f0c105bc59";
    };
    doCheck = false;
}
