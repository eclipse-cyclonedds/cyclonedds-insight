[![Website](https://img.shields.io/badge/web-cyclonedds.io-blue)](https://cyclonedds.io)
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
