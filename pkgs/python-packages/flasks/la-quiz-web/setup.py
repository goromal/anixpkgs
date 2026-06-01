from setuptools import setup

setup(
    name='la_quiz_web',
    version='0.0.1',
    py_modules=['la_quiz_web'],
    entry_points={
        'console_scripts': ['la-quiz-web = la_quiz_web:run']
    },
)
