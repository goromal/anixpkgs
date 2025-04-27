from setuptools import setup
setup(
    name='authui',
    version='0.0.0',
    py_modules=['authui'],
    entry_points={
        'console_scripts': ['authui = authui:run']
    },
)
