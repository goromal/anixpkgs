{ clangStdenv
, cmake
, eigen
, boost
, pkg-src
}:
clangStdenv.mkDerivation {
    name = "manif-geom-cpp";
    version = "1.0.0";
    src = pkg-src;
    nativeBuildInputs = [
        cmake
    ];
    buildInputs = [
        eigen
        boost
    ];
    preConfigure = ''
    cmakeFlags="$cmakeFlags --no-warn-unused-cli"
    '';
    meta = {
        description = "Templated, header-only implementations for SO(2), SE(2), SO(3), SE(3).";
        longDescription = ''
            [Repository](https://github.com/goromal/manif-geom-cpp)

            Operationally very similar to variations on Eigen's `Quaternion<T>` class, but with added chart maps and rules for addition and subtraction on tangent spaces. Meant to be used with nonlinear least-squares solvers like Ceres Solver which take advantage of templating to implement auto-differentiation on arbitrary mathematical formulations in code.

            The SO(3) math is based on [my notes](https://notes.andrewtorgesen.com/doku.php?id=public:implementing-rotations) on 3D rotation representations.

            ## Including in Your Project With CMake

            ```cmake
            # ...

            find_package(Eigen3 REQUIRED)
            find_package(manif-geom-cpp REQUIRED)

            include_directories(
                ''${EIGEN3_INCLUDE_DIRS}
            )


            # ...

            target_link_libraries(target INTERFACE manif-geom-cpp)

            ```

            ## Example Usage

            Example usage of SO(3):

            ```cpp
            // action
            SO3d     q = SO3d::random();
            Vector3d v;
            v.setRandom();

            Vector3d qv1 = q * v;
            Vector3d qv2 = q.R() * v;
            BOOST_CHECK_CLOSE(qv1.x(), qv2.x(), 1e-8);
            BOOST_CHECK_CLOSE(qv1.y(), qv2.y(), 1e-8);
            BOOST_CHECK_CLOSE(qv1.z(), qv2.z(), 1e-8);

            // inversion and composition
            SO3d q1    = SO3d::random();
            SO3d q2    = SO3d::random();
            SO3d q2inv = q2.inverse();
            SO3d q1p   = q1 * q2 * q2inv;

            BOOST_CHECK_CLOSE(q1.w(), q1p.w(), 1e-8);
            BOOST_CHECK_CLOSE(q1.x(), q1p.x(), 1e-8);
            BOOST_CHECK_CLOSE(q1.y(), q1p.y(), 1e-8);
            BOOST_CHECK_CLOSE(q1.z(), q1p.z(), 1e-8);

            // Euler conversions
            Vector3d euler;
            euler.setRandom();
            euler *= M_PI;
            SO3d q  = SO3d::fromEuler(euler.x(), euler.y(), euler.z());
            SO3d q2 = SO3d::fromEuler(q.roll(), q.pitch(), q.yaw());

            BOOST_CHECK_CLOSE(q.w(), q2.w(), 1e-8);
            BOOST_CHECK_CLOSE(q.x(), q2.x(), 1e-8);
            BOOST_CHECK_CLOSE(q.y(), q2.y(), 1e-8);
            BOOST_CHECK_CLOSE(q.z(), q2.z(), 1e-8);

            // plus / minus
            SO3d     q1 = SO3d::random();
            Vector3d q12;
            q12.setRandom();
            SO3d     q2   = q1 + q12;
            Vector3d q12p = q2 - q1;
            BOOST_CHECK_CLOSE(q12.x(), q12p.x(), 1e-8);
            BOOST_CHECK_CLOSE(q12.y(), q12p.y(), 1e-8);
            BOOST_CHECK_CLOSE(q12.z(), q12p.z(), 1e-8);

            // chart maps
            SO3d     q = SO3d::random();
            Vector3d w;
            w.setRandom();
            Vector3d qLog = SO3d::Log(q);
            SO3d     q2   = SO3d::Exp(qLog);
            BOOST_CHECK_CLOSE(q.w(), q2.w(), 1e-8);
            BOOST_CHECK_CLOSE(q.x(), q2.x(), 1e-8);
            BOOST_CHECK_CLOSE(q.y(), q2.y(), 1e-8);
            BOOST_CHECK_CLOSE(q.z(), q2.z(), 1e-8);

            SO3d     wExp = SO3d::Exp(w);
            Vector3d w2   = SO3d::Log(wExp);
            BOOST_CHECK_CLOSE(w.x(), w2.x(), 1e-8);
            BOOST_CHECK_CLOSE(w.y(), w2.y(), 1e-8);
            BOOST_CHECK_CLOSE(w.z(), w2.z(), 1e-8);

            // scaling
            SO3d qI  = SO3d::identity();
            SO3d qIs = 5.0 * qI;
            BOOST_CHECK_CLOSE(qIs.w(), qI.w(), 1e-8);
            BOOST_CHECK_CLOSE(qIs.x(), qI.x(), 1e-8);
            BOOST_CHECK_CLOSE(qIs.y(), qI.y(), 1e-8);
            BOOST_CHECK_CLOSE(qIs.z(), qI.z(), 1e-8);

            SO3d qr  = SO3d::random();
            SO3d qr2 = qr * 0.2; // if scale is too big, then the rotation will
                                // wrap around the sphere, resulting in a reversed
                                // or truncated tangent vector which can't be inverted
                                // through scalar division
            SO3d qr3 = qr2 / 0.2;
            BOOST_CHECK_CLOSE(qr.w(), qr3.w(), 1e-8);
            BOOST_CHECK_CLOSE(qr.x(), qr3.x(), 1e-8);
            BOOST_CHECK_CLOSE(qr.y(), qr3.y(), 1e-8);
            BOOST_CHECK_CLOSE(qr.z(), qr3.z(), 1e-8);
            ```

            ## Conventions

            ### Ordering

            Scalar term first:

            $$\mathbf{R} \in SO(2) \triangleq \begin{bmatrix} q_w & q_x \end{bmatrix}.$$

            $$\mathbf{R} \in SO(3) \triangleq \begin{bmatrix} q_w & q_x & q_y & q_z \end{bmatrix}.$$

            ### Handedness

            Right-handed:

            $$\mathbf{q}_1 \otimes \mathbf{q}_2=[\mathbf{q}_1]_L\mathbf{q}_2=[\mathbf{q}_2]_R\mathbf{q}_1,$$

            $$[\mathbf{q}]_L \triangleq \begin{bmatrix}q_w & -q_x & -q_y & -q_z \\\ q_x & q_w & -q_z & q_y \\\ q_y & q_z & q_w & -q_x \\\ q_z & -q_y & q_x & q_w\end{bmatrix},$$

            $$[\mathbf{q}]_R \triangleq \begin{bmatrix}q_w & -q_x & -q_y & -q_z \\\ q_x & q_w & q_z & -q_y \\\ q_y & -q_z & q_w & q_x \\\ q_z & q_y & -q_x & q_w \end{bmatrix}.$$

            ### Function

            Passive:

            $$\mathbf{R}_A^B~^A\mathbf{v}=^B\mathbf{v}.$$

            ### Directionality and Perturbation

            Body-to-world with local perturbations:

            $$\mathbf{R}_B^W \oplus \tilde{\theta} \triangleq \mathbf{R}_B^W \text{Exp}\left(\tilde{\theta}\right).$$
        '';
    };
}
