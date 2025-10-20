rm -r ./deps &&
export CYCLONEDDS_HOME=$PWD/deps/cyclonedds/build/install &&
export CYCLONEDDS_PYTHON_HOME=$PWD/deps/cyclonedds-python && 
mkdir -p deps && 
cd deps && 
python3 -m venv venv && 
source venv/bin/activate && 
git clone https://github.com/eclipse-cyclonedds/cyclonedds.git && 
cd cyclonedds && mkdir build && cd build && 
cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=./install -DENABLE_SSL=off -DENABLE_SECURITY=off .. && cmake --build . --config Release --target install && 
cd ../.. && 
git clone https://github.com/eclipse-cyclonedds/cyclonedds-python.git && 
cd cyclonedds-python && 
pip3 install -e . && 
pip3 install -r ../../requirements.txt && 
cd ../.. && 
pyside6-rcc ./resources.qrc -o ./src/qrc_file.py && \
DYLD_LIBRARY_PATH="$CYCLONEDDS_HOME/lib" \
LD_LIBRARY_PATH="$CYCLONEDDS_HOME/lib:$LD_LIBRARY_PATH" \
pyinstaller main.spec --noconfirm --clean
if [ "$(uname)" == "Linux" ]; then
    pyinstaller src/updater.py --onefile --name Updater -i "NONE" --distpath "./dist/CycloneDDS Insight" --noconsole --noconfirm --clean
fi
