set "CYCLONEDDS_HOME=%cd%\deps\cyclonedds\build\install" && ^
set "CYCLONEDDS_PYTHON_HOME=%cd%\deps\cyclonedds-python" && ^
mkdir deps && ^
cd deps && ^
python -m venv venv && ^
venv\Scripts\activate && ^
git clone https://github.com/eclipse-cyclonedds/cyclonedds.git && ^
cd cyclonedds && mkdir build && cd build && ^
cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=./install -DENABLE_SSL=off -DENABLE_SECURITY=off .. && cmake --build . --config Release --target install && ^
cd ..\.. && ^
git clone https://github.com/eclipse-cyclonedds/cyclonedds-python.git && ^
cd cyclonedds-python && ^
pip install -e . && ^
pip install -r ..\..\requirements.txt && ^
cd ..\.. && ^
set PATH=%PATH%;%CYCLONEDDS_HOME%\bin && ^
pyside6-rcc ./resources.qrc -o ./src/qrc_file.py && ^
pyinstaller main.spec --noconfirm --clean && ^
.\deps\venv\Scripts\deactivate && ^
iscc setup.iss /DTheAppVersion=0.0.0
