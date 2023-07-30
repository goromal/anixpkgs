{ clangStdenv
, cmake
, boost
, pkg-src
}:
clangStdenv.mkDerivation {
    name = "sorting";
    version = "1.0.0";
    src = pkg-src;
    nativeBuildInputs = [
        cmake
    ];
    buildInputs = [
        boost
    ];
    preConfigure = ''
    cmakeFlags="$cmakeFlags --no-warn-unused-cli"
    '';
    meta = {
        description = "A C++ library for sporadic, incremental sorting with client-side comparators.";
        longDescription = ''
        [Repository](https://github.com/goromal/sorting)

        [Tests](https://github.com/goromal/sorting/blob/master/tests/SortingTest.cpp)

        The main idea of this library is to take sorting algorithms like Quicksort and make them *stateless*
        across iterations. The sorting is performed within the "server" one step at a time where all the state information needed to perform
        the next step in the sort is passed in as an input from a "client." The client must keep track of this state
        and also perform the binary comparisons requested by the server at each step.

        This non-traditional conception of sorting effectively allows a human to be placed in the middle of the sorting loop,
        dictating the atomic binary comparisons between elements in a sortable set. Since the outcomes of these comparisons dictate the
        final ordering of the elements from the sorting algorithm, this design provides a natural (and thorough) way for a person to topologically rank
        arbitrary sets of objects through the cognitively manageable task of successive binary choices of preference. The [rankserver](./rankserver-cpp.md)
        experiment is powered by this library.
        '';
    };
}
