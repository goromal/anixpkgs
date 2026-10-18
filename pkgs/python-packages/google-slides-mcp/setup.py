from setuptools import setup

setup(
    name="google-slides-mcp",
    version="1.0.0",
    py_modules=["google_slides_mcp_server"],
    install_requires=["google-api-python-client", "google-auth"],
    entry_points={
        "console_scripts": ["google-slides-mcp-server = google_slides_mcp_server:main"]
    },
)
