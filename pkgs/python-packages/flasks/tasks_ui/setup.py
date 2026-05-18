from setuptools import setup

setup(
    name='tasks_ui',
    version='0.0.1',
    py_modules=['tasks_ui'],
    entry_points={
        'console_scripts': ['tasks_ui = tasks_ui:run']
    },
)
