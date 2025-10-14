set "CYCLONEDDS_HOME=%cd%\deps\cyclonedds\build\install" && ^
set "CYCLONEDDS_PYTHON_HOME=%cd%\deps\cyclonedds-python" && ^
.\deps\venv\Scripts\activate.bat && ^
pyside6-rcc .\resources.qrc -o .\src\qrc_file.py && ^
python .\src\main.py --loglevel=trace