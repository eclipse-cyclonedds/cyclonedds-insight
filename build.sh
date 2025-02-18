


export CYCLONEDDS_HOME=$PWD/deps/cyclonedds/build/install
export CYCLONEDDS_PYTHON_HOME=$PWD/deps/cyclonedds-python

rm -fr deps/cyclonedds
rm -fr deps/cyclonedds-python

mkdir -p deps && \
cd deps && \
python3 -m venv venv && \
source venv/bin/activate && \
git clone https://github.com/eclipse-cyclonedds/cyclonedds.git && \
cd cyclonedds && mkdir -p build && cd build && \
cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=./install -DENABLE_SSL=off -DENABLE_SECURITY=off .. && cmake --build . --config Release --target install -j 4 && \
cd ../.. && \
git clone https://github.com/eclipse-cyclonedds/cyclonedds-python.git && \
cd cyclonedds-python && \
pip install -e . && \
pip install -r ../../requirements.txt && \
cd ../.. && \
pyside6-rcc ./resources.qrc -o ./src/qrc_file.py && \
python3 ./src/main.py