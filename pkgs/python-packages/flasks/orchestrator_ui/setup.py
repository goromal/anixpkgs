from setuptools import setup
setup(
    name='orchestrator_ui',
    version='0.0.0',
    py_modules=['orchestrator_ui'],
    entry_points={
        'console_scripts': ['orchestrator_ui = orchestrator_ui:run']
    },
)
