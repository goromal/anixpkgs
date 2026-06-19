from setuptools import setup

setup(
    name="intake_ui",
    version="0.0.1",
    py_modules=["intake_ui"],
    entry_points={"console_scripts": ["intake_ui = intake_ui:run"]},
)
