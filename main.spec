"""
 * Copyright(c) 2024 Sven Trittler
 *
 * This program and the accompanying materials are made available under the
 * terms of the Eclipse Public License v. 2.0 which is available at
 * http://www.eclipse.org/legal/epl-2.0, or the Eclipse Distribution License
 * v. 1.0 which is available at
 * http://www.eclipse.org/org/documents/edl-v10.php.
 *
 * SPDX-License-Identifier: EPL-2.0 OR BSD-3-Clause
"""

import os

cyclonedds_home = os.getenv('CYCLONEDDS_HOME', './')
print('cyclonedds_home: ' + cyclonedds_home)

cyclonedds_python_home = os.getenv('CYCLONEDDS_PYTHON_HOME', './')
print('cyclonedds_python_home: ' + cyclonedds_python_home)

bins = []

if os.name == 'nt':
    bins.append((f"{cyclonedds_home}/bin/*.dll", '.'))
    bins.append((f"{cyclonedds_home}/bin/idlc.exe", '.'))

a = Analysis(
    ['src/main.py'],
    pathex=[cyclonedds_python_home],
    binaries=bins,
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
    icon='./res/images/cyclonedds.ico'
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
    version='0.0.0'
)
