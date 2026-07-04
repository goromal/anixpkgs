from setuptools import setup

setup(
    name="sunset",
    version="0.0.1",
    py_modules=["sunset"],
    entry_points={
        "console_scripts": [
            "sunset=sunset:main",
        ],
    },
)
