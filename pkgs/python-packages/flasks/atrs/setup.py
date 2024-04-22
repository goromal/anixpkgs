from setuptools import setup
setup(
    name='atrs',
    version='0.0.0',
    py_modules=['atrs'],
    entry_points={
        'console_scripts': ['atrs = atrs:run']
    },
)
