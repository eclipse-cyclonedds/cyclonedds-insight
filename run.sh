export CYCLONEDDS_HOME=$PWD/deps/cyclonedds/build/install
export CYCLONEDDS_PYTHON_HOME=$PWD/deps/cyclonedds-python

export CYCLONEDDS_URI=file://$PWD/cyclone.xml

source deps/venv/bin/activate && \
pyside6-rcc ./resources.qrc -o ./src/qrc_file.py && \
python3 ./src/main.py --loglevel=trace