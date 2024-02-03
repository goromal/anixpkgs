from setuptools import setup
setup(
    name='stampserver',
    version='0.0.0',
    py_modules=['stampserver'],
    entry_points={
        'console_scripts': ['stampserver = stampserver:run']
    },
)
