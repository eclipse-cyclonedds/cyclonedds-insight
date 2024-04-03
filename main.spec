# -*- mode: python ; coding: utf-8 -*-

import os

cyclonedds_python_home = os.getenv('CYCLONEDDS_PYTHON_HOME', './')
print('cyclonedds_python_home: ' + cyclonedds_python_home)

a = Analysis(
    ['src/main.py'],
    pathex=[cyclonedds_python_home],
    binaries=[],
    datas=[],
    hiddenimports=[],
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=[],
    noarchive=False,
)
pyz = PYZ(a.pure)

exe = EXE(
    pyz,
    a.scripts,
    [],
    exclude_binaries=True,
    name='CycloneDDS Insight',
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=True,
    console=False,
    disable_windowed_traceback=False,
    argv_emulation=False,
    target_arch=None,
    codesign_identity=None,
    entitlements_file=None,
)
coll = COLLECT(
    exe,
    a.binaries,
    a.datas,
    strip=False,
    upx=True,
    upx_exclude=[],
    name='CycloneDDS Insight',
)
app = BUNDLE(coll,
    name='CycloneDDS Insight.app',
    icon='./res/images/icon.icns',
    bundle_identifier=None,
    version='1.0.0'
)
