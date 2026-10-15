{
  lib,
  rustPlatform,
  pkg-src,
}:
rustPlatform.buildRustPackage rec {
  pname = "manif-geom-rs";
  version = "0.1.0";
  src = pkg-src;
  cargoHash = "sha256-Y7pS5WeFLRdj9jrWiA/kbHdzkdZL+eEZ9Ft0Wh2XNr0=";
  meta = {
    description = "Rust implementations of SO(2), SE(2), SO(3), and SE(3), compatible with manif-geom-cpp.";
    longDescription = ''
      [Repository](https://github.com/goromal/manif-geom-rs)

      Provides complete 2D and 3D rotation and rigid-transform Lie groups,
      including matrix conversions, point actions, composition, inverse,
      exponential and logarithmic maps, right-side perturbations, contiguous
      coefficient access, scalar casts, and nalgebra quaternion interop.

      Coefficient and tangent ordering follow
      [manif-geom-cpp](https://github.com/goromal/manif-geom-cpp).
    '';
  };
}
