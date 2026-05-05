from setuptools import setup
setup(
    name='rankserver',
    version='0.0.0',
    py_modules=['rankserver'],
    entry_points={
        'console_scripts': ['rankserver = rankserver:run']
    },
)
