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

import sys
import os
import platform

# Execution before first import of cyclonedds
if getattr(sys, 'frozen', False):
    APPLICATION_PATH = sys._MEIPASS
    # remove the env variable early to ensure that
    # cyclonedds-python will pick the correct libs
    # provided by the app bundle
    if "CYCLONEDDS_HOME" in os.environ:
        del os.environ["CYCLONEDDS_HOME"]
    if platform.system() == "Linux":
        # https://bugreports.qt.io/browse/QTBUG-114635
        os.environ["QT_QPA_PLATFORM"] = "xcb" 
else:
    APPLICATION_PATH = os.path.dirname(os.path.abspath(__file__))
    # In non-bundle mode we need the path to idlc executable
    cyclonedds_home = os.getenv('CYCLONEDDS_HOME')
    if not cyclonedds_home:
        raise Exception('CYCLONEDDS_HOME environment variable is not set.')
    else:
        print('cyclonedds_home: ' + cyclonedds_home)

from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine, qmlRegisterType
from PySide6.QtCore import qInstallMessageHandler, QUrl, QThread, qVersion
from PySide6.QtGui import QIcon, QPixmap
from PySide6.QtQuickControls2 import QQuickStyle
import logging
from dds_access import dds_data
from dds_access.dds_utils import getConfiguredDomainIds
from models.overview_model import TreeModel, TreeNode
from models.endpoint_model import EndpointModel
from models.datamodel_model import DatamodelModel
from models.tester_model import TesterModel
from utils import qt_message_handler, setupLogger
from models.participant_model import ParticipantTreeModel, ParticipantTreeNode
import utils
from version import CYCLONEDDS_INSIGHT_VERSION
from module_handler import DataModelHandler

# generated by pyside6-rcc
import qrc_file 

from dataclasses import dataclass

import cyclonedds.idl as idl
import cyclonedds.idl.annotations as annotate
import cyclonedds.idl.types as types

@dataclass
@annotate.final
@annotate.autoid("sequential")
class Vehicle(idl.IdlStruct, typename="vehicles.Vehicle"):
    name: str
    x: types.int64
    y: types.int64


if __name__ == "__main__":
    app = QGuiApplication(sys.argv)
    app.setWindowIcon(QIcon(QPixmap(":/res/images/cyclonedds.png")))
    app.setApplicationName("CycloneDDS Insight")
    app.setApplicationDisplayName("CycloneDDS Insight")
    app.setOrganizationName("cyclonedds")
    app.setOrganizationDomain("org.eclipse.cyclonedds.insight")

    # Setup the logger
    utils.setupLogger(logging.DEBUG)

    # Print qml log messages into the python log
    qInstallMessageHandler(utils.qt_message_handler)

    logging.info(f"Starting CycloneDDS Insight Version {CYCLONEDDS_INSIGHT_VERSION} ({utils.getBuildInfoGitHashShort()}) ...")
    logging.debug(f"Branch: {utils.getBuildInfoGitBranch()}")
    logging.debug(f"Commit: {utils.getBuildInfoGitHash()}")
    logging.debug(f"CycloneDDS-Python: {utils.getBuildInfoCyclonePythonGitHash()}")
    logging.debug(f"CycloneDDS: {utils.getBuildInfoCycloneGitHash()}")
    logging.debug(f"Application path: {APPLICATION_PATH}")
    logging.debug(f"Python version: {str(sys.version)}")
    logging.debug(f"Qt version: {qVersion()}")

    if sys.platform == "darwin":
        QQuickStyle.setStyle("macOS")
    else:
        QQuickStyle.setStyle("Fusion")

    worker_thread = QThread()
    data = dds_data.DdsData()
    data.moveToThread(worker_thread)
    worker_thread.finished.connect(data.deleteLater)
    worker_thread.start()

    rootItem = TreeNode("Root")
    treeModel = TreeModel(rootItem)
    threads = {}
    dataModelHandler: DataModelHandler = DataModelHandler()
    datamodelRepoModel = DatamodelModel(threads, dataModelHandler)
    testerModel = TesterModel(threads, dataModelHandler)
    datamodelRepoModel.newWriterSignal.connect(testerModel.addWriter)
    participantRootItem = ParticipantTreeNode("Root")
    participantModel = ParticipantTreeModel(participantRootItem)

    qmlUtils = utils.QmlUtils()

    engine = QQmlApplicationEngine()
    engine.rootContext().setContextProperty("treeModel", treeModel)
    engine.rootContext().setContextProperty("participantModel", participantModel)
    engine.rootContext().setContextProperty("datamodelRepoModel", datamodelRepoModel)
    engine.rootContext().setContextProperty("testerModel", testerModel)
    engine.rootContext().setContextProperty("qmlUtils", qmlUtils)
    engine.rootContext().setContextProperty("CYCLONEDDS_URI", os.getenv("CYCLONEDDS_URI", "<not set>"))
    engine.rootContext().setContextProperty("CYCLONEDDS_INSIGHT_VERSION", CYCLONEDDS_INSIGHT_VERSION)
    engine.rootContext().setContextProperty("CYCLONEDDS_INSIGHT_GIT_HASH_SHORT", utils.getBuildInfoGitHashShort())
    engine.rootContext().setContextProperty("CYCLONEDDS_PYTHON_GIT_HASH_SHORT", utils.getBuildInfoCyclonePythonGitHashShort())
    engine.rootContext().setContextProperty("CYCLONEDDS_GIT_HASH_SHORT", utils.getBuildInfoCycloneGitHashShort())
    engine.rootContext().setContextProperty("CYCLONEDDS_INSIGHT_GIT_HASH", utils.getBuildInfoGitHash())
    engine.rootContext().setContextProperty("CYCLONEDDS_PYTHON_GIT_HASH", utils.getBuildInfoCyclonePythonGitHash())
    engine.rootContext().setContextProperty("CYCLONEDDS_GIT_HASH", utils.getBuildInfoCycloneGitHash())
    engine.rootContext().setContextProperty("CYCLONEDDS_INSIGHT_GIT_BRANCH", utils.getBuildInfoGitBranch())
    engine.rootContext().setContextProperty("CYCLONEDDS_INSIGHT_BUILD_ID", utils.getBuildId())
    engine.rootContext().setContextProperty("CYCLONEDDS_INSIGHT_BUILD_PIPELINE_ID", utils.getBuildPipelineId())

    qmlRegisterType(EndpointModel, "org.eclipse.cyclonedds.insight", 1, 0, "EndpointModel")

    testVeh = Vehicle(None, None, None)
    print(testVeh)
    testVeh.name = "test"
    print(testVeh)


    engine.load(QUrl("qrc:/src/views/main.qml"))
    if not engine.rootObjects():
        logging.critical("Failed to load qml")
        sys.exit(-1)

    # Add all configured domains
    domainIds = getConfiguredDomainIds()    
    for domainId in domainIds:
        data.add_domain(domainId)

    # fallback
    if len(domainIds) == 0:
        data.add_domain(0)

    logging.info("qt ...")
    ret_code = app.exec()
    logging.info("qt ... DONE")

    logging.info("Clean up ...")
    datamodelRepoModel.shutdownEndpoints()
    data.join_observer()
    worker_thread.quit()
    worker_thread.wait()
    logging.info("Clean up ... DONE")

    sys.exit(ret_code)
