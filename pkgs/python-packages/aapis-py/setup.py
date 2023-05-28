from setuptools import setup, find_namespace_packages

setup(
    name = "aapis-py",
    version = "0.0.0",
    author = "Andrew Torgesen",
    author_email = "andrew.torgesen@gmail.com",
    description="Python bindings for aapis",
    install_requires=["protobuf"],
    packages=find_namespace_packages(where="aapis_py"),
    package_dir={"": "aapis_py"},
    package_data={"": ["aapis.desc", "py.typed", "*.pyi"]},
)
