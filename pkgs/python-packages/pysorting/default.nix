{ callPackage, clangStdenv, cmake, sorting, pybind11, python, pythonOlder
, pytestCheckHook, buildPythonPackage, pkg-src }:
callPackage ../pythonPkgFromPybind.nix {
  pname = "pysorting";
  version = "1.0.0";
  description = "RESTful incremental sorting with client-side comparators.";
  inherit clangStdenv;
  inherit pkg-src;
  cppNativeBuildInputs = [ cmake ];
  cppBuildInputs = [ sorting ];
  hasTests = true;
  inherit pybind11;
  inherit python;
  inherit pythonOlder;
  inherit pytestCheckHook;
  inherit buildPythonPackage;
  propagatedBuildInputs = [ ];
  checkPkgs = [ ];
  longDescription = ''
    [Repository](https://github.com/goromal/pysorting)

    This library is a Python-wrapped version of the C++ [sorting](../cpp/sorting.md) library. As such, it is meant to be used in conjunction with a client that can solicit answers to binary comparisons for the purpose of incremental sorting.

    Example usage in a Python script:

    ```python
    # key-value pairs to be sorted by values
    values = {0: 4.8, 1: 10.0, 2: 1.0, 3: 2.5, 4: 5.0}

    state = QuickSortState()
    state.n = 5
    state.arr = [i for i in values.keys()]
    state.stack = [0 for i in range(state.n)]
    # validateState(state)

    # proxy for user choices from some client; this will simply choose the larger
    # value, resulting in an ascending sort
    def updateComparator(a, b):
        if a < b:
            return int(ComparatorResult.LEFT_LESS)
        elif a > b:
            return int(ComparatorResult.LEFT_GREATER)
        else:
            return int(ComparatorResult.LEFT_EQUAL)
        
    # simulate user choices until the list is sorted
    iter = 0
    maxIters = 50
    while not (state.top == UINT32_MAX and state.c != 0) and iter < maxIters:
        iter_success, state_out = restfulQuickSort(state)
        state = state_out
        if state.l == int(ComparatorLeft.I):
            state.c = updateComparator(values[state.arr[state.i]], values[state.arr[state.p]])
        elif state.l == int(ComparatorLeft.J):
            state.c = updateComparator(values[state.arr[state.j]], values[state.arr[state.p]])
        iter += 1
        
    # sorted keys
    # state.arr == [2, 3, 0, 4, 1]
    ```
  '';
}
