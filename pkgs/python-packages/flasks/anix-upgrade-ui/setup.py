from setuptools import setup

setup(
    name="anix-upgrade-ui",
    version="0.0.1",
    py_modules=["anix_upgrade_ui", "run_store"],
    entry_points={
        "console_scripts": [
            "anix-upgrade-ui=anix_upgrade_ui:main",
        ],
    },
)
