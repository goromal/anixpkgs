# find_rotational_conventions

Find rotational conventions of a Python transform library.

[Gist](https://gist.github.com/goromal/fb15f44150ca4e0951acaee443f72d3e)

Conventions are defined in my [notes on rotations](https://andrewtorgesen.com/notes/Autonomy/Math_Fundamentals/3D_Geometry/Rotations_Robotics_Field_Guide.html). Example deduction of conventions used in the [geometry](./geometry.md) library:

```python
from find_rotational_conventions import (                                
    find_euler_conventions,                                              
    find_axis_angle_conventions,                                         
    find_quaternion_conventions,                                         
)                                                                        
import numpy as np                                                       
from typing import Tuple                                                 
from geometry import SO3 # https://github.com/goromal/geometry           
                                                                        
LIBNAME = "manif-geom-cpp/geometry" # Library being tested               
                                                                        
def euler2R(arg1: float, arg2: float, arg3: float) -> np.ndarray:        
    return SO3.fromEuler(arg1, arg2, arg3).R()                           
                                                                        
def axisAngle2R(axis: np.ndarray, angle: float) -> np.ndarray:           
    return SO3.fromAxisAngle(axis, angle).R()                            
                                                                        
def quat2R(q1: float, q2: float, q3: float, q4: float) -> np.ndarray:    
    return SO3.fromQuat(q1, q2, q3, q4).R()                              
                                                                        
def quatComp(                                                            
    q1: Tuple[float, float, float, float],                               
    q2: Tuple[float, float, float, float]                                
) -> Tuple[float, float, float, float]:                                  
    q = SO3.fromQuat(*q1) * SO3.fromQuat(*q2)                            
    return (q.w(), q.x(), q.y(), q.z())                                  
                                                                        
find_axis_angle_conventions(LIBNAME, axisAngle2R)                        
find_euler_conventions(LIBNAME, euler2R)                                 
find_quaternion_conventions(LIBNAME, quat2R, quatComp)
```

Yields the output:

```
Axis-Angle Conventions for manif-geom-cpp/geometry:

    Rodrigues Directionality: Body-to-World


Euler Angle Conventions for manif-geom-cpp/geometry:

    Euler Argument Order: ['x', 'y', 'z']
    Euler Matrix Order:   R = R(z)R(y)R(x)
    Euler Directionality: Body-to-World


Quaternion Conventions for manif-geom-cpp/geometry:

    Quaternion Ordering:       Scalar First
    Quaternion Handedness:     Right-Handed
    Quaternion Function:       Passive
    Quaternion Directionality: Body-to-World
```

## Usage

```bash

NOTE: You're running find_rotational_conventions.py standalone, but it's most useful as an import to deduce the rotational conventions of the particular library that you're using.

Running an example from the following source code:
=========
test.py |=================================================================
=========                                                                |
from find_rotational_conventions import (                                |
    find_euler_conventions,                                              |
    find_axis_angle_conventions,                                         |
    find_quaternion_conventions,                                         |
)                                                                        |
import numpy as np                                                       |
from typing import Tuple                                                 |
from geometry import SO3 # https://github.com/goromal/geometry           |
                                                                         |
LIBNAME = "manif-geom-cpp/geometry" # Library being tested               |
                                                                         |
def euler2R(arg1: float, arg2: float, arg3: float) -> np.ndarray:        |
    return SO3.fromEuler(arg1, arg2, arg3).R()                           |
                                                                         |
def axisAngle2R(axis: np.ndarray, angle: float) -> np.ndarray:           |
    return SO3.fromAxisAngle(axis, angle).R()                            |
                                                                         |
def quat2R(q1: float, q2: float, q3: float, q4: float) -> np.ndarray:    |
    return SO3.fromQuat(q1, q2, q3, q4).R()                              |
                                                                         |
def quatComp(                                                            |
    q1: Tuple[float, float, float, float],                               |
    q2: Tuple[float, float, float, float]                                |
) -> Tuple[float, float, float, float]:                                  |
    q = SO3.fromQuat(*q1) * SO3.fromQuat(*q2)                            |
    return (q.w(), q.x(), q.y(), q.z())                                  |
                                                                         |
find_axis_angle_conventions(LIBNAME, axisAngle2R)                        |
find_euler_conventions(LIBNAME, euler2R)                                 |
find_quaternion_conventions(LIBNAME, quat2R, quatComp)                   |
                                                                         |
==========================================================================

With output:


Axis-Angle Conventions for manif-geom-cpp/geometry:

    Rodrigues Directionality: Body-to-World


Euler Angle Conventions for manif-geom-cpp/geometry:

    Euler Argument Order: ['x', 'y', 'z']
    Euler Matrix Order:   R = R(z)R(y)R(x)
    Euler Directionality: Body-to-World


Quaternion Conventions for manif-geom-cpp/geometry:

    Quaternion Ordering:       Scalar First
    Quaternion Handedness:     Right-Handed
    Quaternion Function:       Passive
    Quaternion Directionality: Body-to-World

```

