set "CYCLONEDDS_HOME=%cd%\deps\cyclonedds\build\install" && ^
set "CYCLONEDDS_PYTHON_HOME=%cd%\deps\cyclonedds-python" && ^
.\deps\venv\Scripts\activate.bat && ^
pyside6-lrelease .\src\translations\cyclonedds-insight_en.ts && ^
pyside6-lrelease .\src\translations\cyclonedds-insight_de.ts && ^
pyside6-rcc .\resources.qrc -o .\src\qrc_file.py && ^
python .\src\main.py --loglevel=trace