from setuptools import setup

setup(
    name='tester',
    version='0.0.1',
    py_modules=['tester'],
    entry_points={
        'console_scripts': ['tester = tester:run']
    },
)
