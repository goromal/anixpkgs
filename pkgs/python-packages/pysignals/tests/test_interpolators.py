import pytest
import numpy as np
from geometry import SO3
from pysignals import LinearInterpolator

t_1 = 1.0
t_2 = 2.0
so3_1 = SO3.fromEuler(0.1, -1.4, 2.0)
so3_2 = SO3.fromEuler(3.0, 0.0, -2.0)

class TestLinearInterpolator:
    def test_so3_interp(self):
        t_data = [t_1, t_2]
        y_data = [so3_1, so3_2]
        interp = LinearInterpolator(t_data, y_data)
        t_mid = (t_1 + t_2)/2.0
        y_mid = so3_1 + (so3_2 - so3_1) / 2.0
        y_mid_interp = interp.at(t_mid)
        assert np.allclose(y_mid.array(), y_mid_interp.array())

    def test_so3_extrap(self):
        t_data = [t_1, t_2]
        y_data = [so3_1, so3_2]
        interp = LinearInterpolator(t_data, y_data)
        y_extrap = interp.at(t_2 + 1.0)
        assert np.allclose(so3_2.array(), y_extrap.array())
