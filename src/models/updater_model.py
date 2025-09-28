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

from PySide6.QtCore import QModelIndex, Qt, QThread, Signal, Slot, QProcess, QObject, QTemporaryDir
from PySide6.QtWidgets import QApplication
from loguru import logger as logging
import requests
import os
import sys
from threading import Lock
import zipfile
import shutil
import tarfile


def getWindowsInstallPath(app_name: str):
    import winreg
    path = None

    uninstall_keys = [
        r"SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
        r"SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall",
    ]

    for root in [winreg.HKEY_LOCAL_MACHINE, winreg.HKEY_CURRENT_USER]:
        for uninstall_key in uninstall_keys:
            try:
                with winreg.OpenKey(root, uninstall_key) as key:
                    for i in range(0, winreg.QueryInfoKey(key)[0]):
                        subkey_name = winreg.EnumKey(key, i)
                        if subkey_name.endswith("_is1") and app_name.lower() in subkey_name.lower():
                            with winreg.OpenKey(key, subkey_name) as subkey:
                                try:
                                    path = winreg.QueryValueEx(subkey, "InstallLocation")[0]
                                    if os.path.exists(path):
                                        return path
                                except FileNotFoundError:
                                    # fallback: parse from UninstallString
                                    try:
                                        uninstall_str = winreg.QueryValueEx(subkey, "UninstallString")[0]
                                        path = os.path.dirname(uninstall_str)
                                        if os.path.exists(path):
                                            return path
                                    except FileNotFoundError:
                                        pass
            except FileNotFoundError:
                continue

    return None


class WorkerThread(QThread):

    downloadedBytes = Signal(int)
    message = Signal(str)
    installCompleted = Signal()
    error = Signal(str)

    def __init__(self, parent=None):
        super().__init__()
        self.running = False
        self.mutex = Lock()
        self.success = False

    def run(self):
        self.running = True

        self.downloadFile(self.organization, self.project, self.buildId)

        logging.trace("WorkerThread stopped")

    def _download_file(self, url, local_filename):
        with requests.get(url, stream=True) as r:
            r.raise_for_status()
            with open(local_filename, 'wb') as f:
                total_bytes = 0
                for chunk in r.iter_content(chunk_size=8192):
                    if not self.running:
                        raise ValueError("Download canceled by user")
                    if chunk:
                        f.write(chunk)
                        total_bytes += len(chunk)
                        self.downloadedBytes.emit(total_bytes)
        return local_filename

    @Slot(str, str, str)
    def setDownloadInfo(self, organization, project, buildId, appDir):
        self.organization = organization
        self.project = project
        self.buildId = buildId
        self.appDir = appDir

    @Slot()
    def stop(self):
        self.running = False

    @Slot(str, str, str)
    def downloadFile(self, organization, project, buildId):
        try:
            url = f"https://dev.azure.com/{organization}/{project}/_apis/build/builds/{buildId}/artifacts?api-version=7.0"
            response = requests.get(url)
            response.raise_for_status()

            data = response.json()

            self.installCompleted.emit()
            logging.debug(f"Artifacts response: {data}")

            if "value" in data:
                targetName = None
                for artifact in data["value"]:
                    if "name" in artifact:
                        artifactName = artifact["name"]

                        platform = sys.platform
                        
                        if platform.startswith("linux"):
                            logging.info("Running on Linux")
                            targetName = "linux"
                        elif platform == "darwin":
                            logging.info("Running on macOS")
                            targetName = "macos"
                        elif platform.startswith("win"):
                            logging.info("Running on Windows")
                            targetName = "windows"
                        else:
                            logging.info(f"Unknown platform: {platform}")
                            raise ValueError(f"Unknown platform: {platform}")

                        if targetName in artifactName.lower():
                            logging.info(f"saw artifact: {artifactName} for platform: {targetName}")
                            break

                logging.info(f"Downloading artifact for platform: {targetName} ...")
                if targetName and "resource" in artifact:
                    download_url = artifact["resource"]["downloadUrl"]
                    file_name = artifactName + ".zip"
                    temp_dir = QTemporaryDir()
                    if temp_dir.isValid():
                        path = temp_dir.path()
                        logging.debug(f"Temporary folder created at: {path}")
                    else:
                        logging.error("Failed to create temporary folder")
                    file_path = os.path.join(path, file_name)
                    self._download_file(download_url, file_path)

                    self.installCompleted.emit()
                    self.message.emit("Extracting ...")

                    with zipfile.ZipFile(file_path, 'r') as zip_ref:
                        zip_ref.extractall(path)
                    logging.info(f"Unzipped artifact to: {path}")

                    # Extract .tar.gz files in the artifact directory
                    appPath = self.appDir
                    if self.appDir == "":
                        appPath = sys._MEIPASS
                    if appPath.endswith("/Contents/Frameworks"):
                        appPath = appPath[:appPath.rfind("/Contents/Frameworks")]

                    logging.debug(f"appPath={appPath}")
                    artifact_dir = os.path.dirname(appPath)
                    logging.debug(f"Artifact directory: {artifact_dir}")

                    tar_gz_path = os.path.join(path, artifactName)
                    pkgFileEnding = ".exe" if platform.startswith("win") else ".tar.gz"
                    tar_gz_path = os.path.join(tar_gz_path, f"{artifactName}{pkgFileEnding}")

                    self.installCompleted.emit()
                    self.message.emit("Installing ...")

                    # Install the application
                    if platform == "darwin":
                        with tarfile.open(tar_gz_path, "r:gz") as tar:
                            tar.extractall(artifact_dir)
                        logging.info(f"Extracted {tar_gz_path} to {artifact_dir}")
                    elif platform.startswith("linux"):
                        tempUnarchivedFolder = QTemporaryDir()
                        logging.info(f"Extract {tar_gz_path} to {tempUnarchivedFolder.path()}")
                        with tarfile.open(tar_gz_path, "r:gz") as tar:
                            tar.extractall(tempUnarchivedFolder.path())
                        logging.info(f"Copy files to {artifact_dir}")
                        shutil.copytree(tempUnarchivedFolder.path(), artifact_dir, dirs_exist_ok=True)
                        logging.info(f"Copy done")
                        appPath = f"{appPath}{os.sep}CycloneDDS Insight"
                    elif platform.startswith("win"):
                        logging.info(f"Running windows installer {tar_gz_path}")
                        winInstallProcess = QProcess()
                        winInstallProcess.setProgram(tar_gz_path)
                        winInstallProcess.setArguments(["/SP-", "/VERYSILENT", "/SUPPRESSMSGBOXES", "/NORESTART", "/FORCECLOSEAPPLICATIONS"])
                        winInstallProcess.start()
                        winInstallProcess.waitForFinished(-1)
                        appPath = f"{appPath}{os.sep}CycloneDDS Insight.exe"
                        install_path = getWindowsInstallPath("{FC901B87-B2DD-4DB7-B317-ADA9B708841F}")
                        if install_path:
                            appPath = install_path + os.sep + "CycloneDDS Insight.exe"
                        else:
                            raise ValueError("Could not determine installation path from registry.")

                    # Launch the application
                    self.installCompleted.emit()
                    self.message.emit("Launch ...")
                    logging.info(f"Launching the new application instance... {appPath}")
                    process = QProcess()
                    if platform == "darwin":
                        process.setProgram("sh")
                        process.setArguments(["-c", f"sleep 2 && open \"{appPath}\""])
                    else:
                        process.setProgram(appPath)

                    success = process.startDetached()
                    if not success:
                        logging.error("Failed to launch the new application instance.")
                        raise ValueError("Failed to launch the new application instance.")

                    logging.info("Update success")
                    self.success = True

                else:
                    logging.error("No suitable artifact found for platform.")

        except Exception as e:
            self.error.emit(str(e))
            logging.error(f"Error: {e}")


class UpdaterModel(QObject):

    updateStepCompleted = Signal(str)
    completed = Signal()
    error = Signal(str)

    def __init__(self, parent=None):
        super().__init__(parent)
        self.worker = None

    @Slot(str, str, str, str)
    def downloadFile(self, organization, project, buildId, appDir):

        if sys.platform == "darwin" or appDir != "":
            logging.info("Running update directly")

            self.updateStepCompleted.emit("Downloading...")
            self.worker = WorkerThread()
            self.worker.downloadedBytes.connect(self.onDownloadedBytes)
            self.worker.installCompleted.connect(self.installCompleted)
            self.worker.error.connect(self.installError)
            self.worker.message.connect(self.installMessage)
            self.worker.setDownloadInfo(organization, project, buildId, appDir)
            self.worker.start()

            self.worker.finished.connect(self.onWorkerFinished)

        else:
            logging.info(f"Update via Updater exe")

            tempdir = QTemporaryDir()
            tempdir.setAutoRemove(False)

            appPath = sys._MEIPASS
            logging.debug(f"appPath raw: {appPath}")
            if appPath.endswith("/_internal"):
                appPath = appPath[:appPath.rfind("/_internal")]
            appDir = appPath

            # Copy a file to cxyz
            updaterExe = "Updater.exe" if sys.platform.startswith("win") else "Updater"
            updaterFilePath = os.path.join(appDir, updaterExe)
            updaterFilePathDest = os.path.join(tempdir.path(), updaterExe)
            logging.info(f"Copied {updaterFilePath} to {updaterFilePathDest}")
            shutil.copy2(updaterFilePath, updaterFilePathDest)

            logging.debug(f"appDir: {appDir}")

            process: QProcess = QProcess()
            process.setWorkingDirectory(tempdir.path())
            process.setProgram("./Updater")
            process.setArguments(["--appDir", appDir, "--organization", organization, "--project", project, "--buildId", buildId])

            success = process.startDetached()
            if success:
                QApplication.quit()
            else:
                logging.error("Failed to launch the Updater executable.")

    @Slot()
    def onWorkerFinished(self):
        logging.debug("Worker thread finished")

        if self.worker:
            logging.info("Exiting the current application instance after successful update...")
            if self.worker.success:
                QApplication.quit()

    @Slot(int)
    def onDownloadedBytes(self, bytes: int):
        mb = bytes / (1024 * 1024)
        self.updateStepCompleted.emit(f"Downloading... ({mb:.0f} MB)")

    @Slot()
    def cancel(self):
        self.updateStepCompleted.emit("Cancelling...")
        if self.worker:
            self.worker.stop()
            self.worker.wait()

    @Slot(str)
    def installMessage(self, message: str):
        self.updateStepCompleted.emit(message)

    @Slot()
    def installCompleted(self):
        self.completed.emit()

    @Slot(str)
    def installError(self, error: str):
        self.error.emit(f"Error: {error}")
