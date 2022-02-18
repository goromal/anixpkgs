# https://github.com/goromal/matlab_utilities/blob/master/math/GeneralizedInterpolator.m

class InterpolatorBase(object):
    # list and list
    def __init__(self, t_data, y_data):
        self.t_data = t_data
        self.n = len(t_data)
        self.y_data = y_data
        self.i = 0

    def at(self, t):
        if t < self.t_data[0]:
            return self.y_data[0]
        if t > self.t_data[-1]:
            return self.y_data[-1]
        if t in self.t_data:
            return self.y_data[self.t_data.index(t)]
        for idx in range(self.n-1):
            self.i = idx
            ti = self.t_data[self.i]
            if ti < t and self._ti(self.i+1) > t:
                return self._interpy(t)
        return None

    def _interpy(self, t):
        return self._yi(self.i) + self._dy(t)

    def _dy(self, t):
        return None

    def _yi(self, i):
        if i < 0:
            return self.y_data[0]
        elif i >= self.n:
            return self.y_data[-1]
        else:
            return self.y_data[i]

    def _ti(self, i):
        if i < 0:
            return self.t_data[0] - 1.0
        elif i >= self.n:
            return self.t_data[-1] + 1.0
        else:
            return self.t_data[i]

class ZeroOrderInterpolator(InterpolatorBase):
    def __init__(self, t_data, y_data, zero_obj):
        super(ZeroOrderInterpolator, self).__init__(t_data, y_data)
        self.zero_obj = zero_obj

    def _dy(self, t):
        return self.zero_obj

class LinearInterpolator(InterpolatorBase):
    def __init__(self, t_data, y_data):
        super(LinearInterpolator, self).__init__(t_data, y_data)

    def _dy(self, t):
        t1 = self._ti(self.i)
        t2 = self._ti(self.i+1)
        y1 = self._yi(self.i)
        y2 = self._yi(self.i+1)
        return (t - t1) / (t2 - t1) * (y2 - y1)

class SplineInterpolator(InterpolatorBase):
    def __init__(self, t_data, y_data):
        super(SplineInterpolator, self).__init__(t_data, y_data)

    def _dy(self, t):
        t0 = self._ti(self.i-1)
        t1 = self._ti(self.i)
        t2 = self._ti(self.i+1)
        t3 = self._ti(self.i+2)
        y0 = self._yi(self.i-1)
        y1 = self._yi(self.i)
        y2 = self._yi(self.i+1)
        y3 = self._yi(self.i+2)
        return (t-t1)/(t2-t1)*((y2-y1) + \
             (t2-t)/(2*(t2-t1)**2)*(((t2-t)*(t2*(y1-y0)+t0*(y2-y1)-t1*(y2-y0)))/(t1-t0) + \
             ((t-t1)*(t3*(y2-y1)+t2*(y3-y1)-t1*(y3-y2)))/(t3-t2)))