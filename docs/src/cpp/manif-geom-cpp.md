# manif-geom-cpp

Templated, header-only implementations for SO(2), SE(2), SO(3), SE(3).

[Repository](https://github.com/goromal/manif-geom-cpp)

Operationally very similar to variations on Eigen's `Quaternion<T>` class, but with added chart maps and rules for addition and subtraction on tangent spaces. Meant to be used with nonlinear least-squares solvers like Ceres Solver which take advantage of templating to implement auto-differentiation on arbitrary mathematical formulations in code.

The SO(3) math is based on [my notes](https://notes.andrewtorgesen.com/doku.php?id=public:implementing-rotations) on 3D rotation representations.

## Including in Your Project With CMake

```cmake
# ...

find_package(Eigen3 REQUIRED)
find_package(manif-geom-cpp REQUIRED)

include_directories(
    ${EIGEN3_INCLUDE_DIRS}
)


# ...

target_link_libraries(target INTERFACE manif-geom-cpp)

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

