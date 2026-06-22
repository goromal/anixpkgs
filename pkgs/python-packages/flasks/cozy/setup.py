from setuptools import setup

setup(
    name='cozy',
    version='0.0.0',
    py_modules=['cozy', 'job_store', 'workflows', 'comfyui_client'],
    entry_points={
        'console_scripts': ['cozy = cozy:run']
    },
)
