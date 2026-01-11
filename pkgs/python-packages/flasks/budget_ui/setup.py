from setuptools import setup
setup(
    name='budget_ui',
    version='0.0.0',
    py_modules=['budget_ui'],
    entry_points={
        'console_scripts': ['budget_ui = budget_ui:run']
    },
)
