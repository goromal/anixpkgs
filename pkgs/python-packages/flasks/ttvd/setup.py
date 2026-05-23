from setuptools import setup
setup(
    name='ttvdserver',
    version='0.0.0',
    py_modules=['ttvdserver'],
    entry_points={
        'console_scripts': ['ttvdserver = ttvdserver:run']
    },
)
