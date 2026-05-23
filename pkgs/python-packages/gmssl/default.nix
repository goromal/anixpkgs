{
  buildPythonPackage,
  fetchurl,
}:
buildPythonPackage rec {
  pname = "gmssl";
  version = "3.2.2";
  format = "wheel";
  src = fetchurl {
    url = "https://files.pythonhosted.org/packages/py3/g/gmssl/gmssl-3.2.2-py3-none-any.whl";
    sha256 = "0s6h5kyhgz3qhxdd9mykckh2rj81xlvd9r3vksdzb7mi3slnkw2r";
  };
  doCheck = false;
  meta = {
    description = "Chinese national standard SM2/SM3/SM4 crypto library";
    longDescription = "Pure-Python implementation of the GM/T cryptographic standards including SM2 (elliptic curve), SM3 (hash), and SM4 (block cipher).";
  };
}
