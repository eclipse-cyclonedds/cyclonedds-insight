[![Website](https://img.shields.io/badge/web-cyclonedds.io-blue)](https://cyclonedds.io)
[![License](https://img.shields.io/badge/License-EPL%202.0-blue)](https://choosealicense.com/licenses/epl-2.0/)
[![License](https://img.shields.io/badge/License-EDL%201.0-blue)](https://choosealicense.com/licenses/edl-1.0/)
[![Community](https://img.shields.io/badge/discord-join%20community-5865f2)](https://discord.gg/BkRYQPpZVV)


# CycloneDDS Insight

A graphical tool to visualize the current DDS system.

![`cyclonedds insight`](res/images/cyclonedds-insight.png)

Features:

- Show topics
- Show reader/writer on a topic
- Show qos of each reader/writer
- Show qos mismatches
- Dark and light mode support
- Runs on MacOS, Windows, Linux

## How to run via python

```bash
# Install dependencies
python3 -m pip install -r requirements.txt

# Execute
pyside6-rcc ./resources.qrc -o ./src/qrc_file.py && python3 ./src/main.py
```

## How to build a standalone MacOS App

```bash
# Execute
export CYCLONEDDS_HOME=<path-to-cyclonedds-install-folder> &&\
export CYCLONEDDS_PYTHON_HOME=<path-to-cyclonedds-python-repo> &&\
pyside6-rcc ./resources.qrc -o ./src/qrc_file.py &&\
DYLD_LIBRARY_PATH="$CYCLONEDDS_HOME/lib" \
pyinstaller main.spec --noconfirm --clean
```

The app is located at `./dist/CycloneDDS Insight.app` after the build.

### Build MacOS Installer

After the build of the standalone MacOS App i can be put into the installer.

```bash
brew install create-dmg # only once
sh ./setup_dmg.sh 0.0.0
```

## How to build a Windows Executable/Installer

```bash
# Build cyclonedds-c
git clone https://github.com/eclipse-cyclonedds/cyclonedds.git
cd cyclonedds && mkdir build && cd build
cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=./install -DENABLE_SSL=off -DENABLE_SECURITY=off .. && cmake --build . --config Release --target install

# Build cyclonedds-python
git clone https://github.com/eclipse-cyclonedds/cyclonedds-python.git
cd cyclonedds-python
set CYCLONEDDS_HOME=<path-to-cyclonedds-home-install>
pip install .

# Build cyclonedds-insight executable
set PATH=%PATH%;%CYCLONEDDS_HOME%\bin
pyinstaller main.spec --noconfirm --clean

# Build cyclonedds-insight setup
iscc setup.iss /DTheAppVersion=0.0.0
```
