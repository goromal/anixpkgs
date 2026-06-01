from setuptools import setup
setup(
    name='vdlserver',
    version='0.0.0',
    py_modules=['vdlserver'],
    entry_points={
        'console_scripts': ['vdlserver = vdlserver:run']
    },
)
