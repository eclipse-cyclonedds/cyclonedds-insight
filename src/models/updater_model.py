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

from PySide6.QtCore import QThread, Signal, Slot, QProcess, QObject, QTemporaryDir
from PySide6.QtCore import QUrl, QSettings
from PySide6.QtNetwork import (
    QNetworkProxy, QNetworkAccessManager, QNetworkRequest, QNetworkReply
)
from PySide6.QtWidgets import QApplication
from loguru import logger as logging
import requests
import os
import sys
from threading import Lock
import zipfile
import shutil
import tarfile
import json
import urllib.parse
import platform


class WorkerThread(QThread):

    downloadedBytes = Signal(int)
    message = Signal(str)
    installCompleted = Signal()
    error = Signal(str)
    proxyAuthRequired = Signal()

    def __init__(self, parent=None):
        super().__init__()
        self.running = False
        self.mutex = Lock()
        self.success = False
        self.settings = QSettings()
        self.proxyUsername = ""
        self.proxyPassword = ""

    @Slot(str, str)
    def setProxyCredentials(self, username: str, password: str):
        logging.info(f"Worker: Set proxy credentials")
        self.proxyUsername = username
        self.proxyPassword = password

    def run(self):
        self.running = True
        self.downloadFile(self.organization, self.project, self.buildId)
        logging.trace("WorkerThread stopped")

    def _download_file(self, url, local_filename):
        logging.info(f"Downloading file from {url} to {local_filename}")
        proxy = self.setupProxy()
        if proxy:
            logging.info(f"Using proxy for download file")
        else:
            logging.info("No proxy for download file")

        with requests.get(url, proxies=proxy ,stream=True) as r:
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

    def setupProxy(self):
        enabled = self.settings.value("proxy/enabled", False, type=bool)
        if enabled:
            host = self.settings.value("proxy/host", "", type=str)
            port = self.settings.value("proxy/port", 8080, type=int)
            logging.info(f"Set proxy: {host}:{port}")
            proxy = {
                "http": f"http://{host}:{port}",
                "https": f"http://{host}:{port}",
            }
            username = urllib.parse.quote(self.proxyUsername)
            password = urllib.parse.quote(self.proxyPassword)
            if username != "" and password != "":
                logging.info("Using proxy with credentials.")
                proxy["http"] = f"http://{username}:{password}@{host}:{port}"
                proxy["https"] = f"http://{username}:{password}@{host}:{port}"
            else:
                logging.info("No Credentials provided.")
            return proxy
        return None

    @Slot(str, str, str)
    def downloadFile(self, organization, project, buildId):
        try:
            proxy = self.setupProxy()
            if proxy:
                logging.info(f"Using proxy for download")
            else:
                logging.info("No proxy for download")

            url = f"https://dev.azure.com/{organization}/{project}/_apis/build/builds/{buildId}/artifacts?api-version=7.0"
            response = None
            try:
                response = requests.get(url, proxies=proxy)
            except Exception as e:
                errorMsg = str(e)
                if "407" in errorMsg:
                    logging.info("Proxy Auth needed.")
                    self.proxyAuthRequired.emit()
                raise ValueError(errorMsg)

            response.raise_for_status()

            data = response.json()

            self.installCompleted.emit()
            logging.debug(f"Artifacts response: {data}")

            if "value" in data:
                targetName = None
                for artifact in data["value"]:
                    if "name" in artifact:
                        artifactName = artifact["name"]

                        arch = platform.machine().lower()
                        if arch == "amd64" or arch == "x86_64":
                            arch = "x64"

                        if sys.platform.startswith("linux"):
                            logging.info("Running on Linux")
                            if arch in artifactName.lower():
                                targetName = "linux"
                        elif sys.platform == "darwin":
                            logging.info("Running on macOS")
                            # on mac os the arch does not matter because of rosetta.
                            targetName = "macos"
                        elif sys.platform.startswith("win"):
                            logging.info("Running on Windows")
                            if arch in artifactName.lower():
                                targetName = "windows"
                        else:
                            logging.info(f"Unknown platform: {sys.platform} {arch}")
                            raise ValueError(f"Unknown platform: {sys.platform} {arch}")

                        if targetName in artifactName.lower():
                            logging.info(f"saw artifact: {artifactName} for platform: {targetName} {arch}")
                            break

                logging.info(f"Downloading artifact for platform: {targetName} ...")
                if targetName and "resource" in artifact:
                    download_url = artifact["resource"]["downloadUrl"]
                    file_name = artifactName + ".zip"
                    temp_dir = QTemporaryDir()
                    temp_dir.setAutoRemove(False)
                    if temp_dir.isValid():
                        path = temp_dir.path()
                        logging.debug(f"Temporary folder created at: {path}")
                    else:
                        raise SystemError("Failed to create temporary folder")
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
                    pkgFileEnding = ".exe" if sys.platform.startswith("win") else ".tar.gz"
                    tar_gz_path = os.path.join(tar_gz_path, f"{artifactName}{pkgFileEnding}")

                    self.installCompleted.emit()
                    self.message.emit("Installing ...")

                    # Install the application
                    process = QProcess()
                    if sys.platform == "darwin":
                        with tarfile.open(tar_gz_path, "r:gz") as tar:
                            tar.extractall(artifact_dir)
                        logging.info(f"Extracted {tar_gz_path} to {artifact_dir}")
                        process.setProgram("sh")
                        process.setArguments(["-c", f"sleep 2 && open \"{appPath}\""])
                    elif sys.platform.startswith("linux"):
                        tempUnarchivedFolder = QTemporaryDir()
                        logging.info(f"Extract {tar_gz_path} to {tempUnarchivedFolder.path()}")
                        with tarfile.open(tar_gz_path, "r:gz") as tar:
                            tar.extractall(tempUnarchivedFolder.path())
                        logging.info(f"Copy files to {artifact_dir}")
                        shutil.copytree(tempUnarchivedFolder.path(), artifact_dir, dirs_exist_ok=True)
                        logging.info(f"Copy done")
                        appPath = f"{appPath}{os.sep}CycloneDDS Insight"
                        process.setProgram(appPath)
                    elif sys.platform.startswith("win"):
                        # Windows installer install and launch the application on the same call
                        process.setProgram(tar_gz_path)
                        process.setArguments(["/SP-", "/SILENT", "/SUPPRESSMSGBOXES", "/NORESTART", "/FORCECLOSEAPPLICATIONS", "/NOCANCEL"])

                    # Launch the application
                    self.installCompleted.emit()
                    self.message.emit("Launch ...")
                    logging.info(f"Launching the new application instance...")
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

    proxyAuthRequired = Signal()
    proxyAuthRequiredUpdater = Signal()

    newBuildFound = Signal(str)
    newBuildError = Signal()

    workerSetProxyCredentialsSignal = Signal(str, str)

    def __init__(self, pipelineId, buildId, currentBranch, parent=None):
        super().__init__(parent)
        self.worker = None
        self.proxyUsername = ""
        self.proxyPassword = ""
        self.settings = QSettings()
        self.proxy = QNetworkProxy()
        self.manager = QNetworkAccessManager()

        # Azure DevOps project details
        self.organization = "eclipse-cyclonedds"
        self.project = "cyclonedds-insight"
        self.masterBranch = "refs/heads/master"
        if currentBranch.startswith("refs/tags/"):
            self.masterBranch = currentBranch
        self.pipelineId = pipelineId
        self.currentBuildId = buildId
        self.currentBranch = currentBranch
        self.latestBuildUrl = QUrl(f"https://dev.azure.com/{self.organization}/{self.project}/_apis/build/builds" +
                        f"?definitions={self.pipelineId}&branchName={self.masterBranch}&statusFilter=succeeded&$top=1&api-version=7.0")

    def requiresRoot(self, appDir):
        return not os.access(appDir, os.R_OK | os.W_OK)

    @Slot(str, str, str, str)
    def downloadFile(self, organization, project, buildId, appDir):

        if sys.platform == "darwin" or appDir != "" or sys.platform.startswith("win"):
            # MacOS and Windows (via installer) can run directly

            logging.info("Running update ...")
            self.updateStepCompleted.emit("Downloading...")
            self.worker = WorkerThread()
            self.worker.downloadedBytes.connect(self.onDownloadedBytes)
            self.worker.installCompleted.connect(self.installCompleted)
            self.worker.proxyAuthRequired.connect(self.workerProxyRequestSlot)
            self.workerSetProxyCredentialsSignal.connect(self.worker.setProxyCredentials)
            self.worker.error.connect(self.installError)
            self.worker.message.connect(self.installMessage)
            self.worker.setDownloadInfo(organization, project, buildId, appDir)
            self.worker.setProxyCredentials(self.proxyUsername, self.proxyPassword)
            self.worker.start()
            self.worker.finished.connect(self.onWorkerFinished)

        else:
            # Only on linux needed
            logging.info(f"Running Updater exe ...")

            tempdir = QTemporaryDir()
            tempdir.setAutoRemove(False)

            appPath = sys._MEIPASS
            logging.debug(f"appPath raw: {appPath}")
            if appPath.endswith(f"{os.sep}_internal"):
                appPath = appPath[:appPath.rfind(f"{os.sep}_internal")]
            appDir = appPath

            # Copy a file to cxyz
            updaterExe = "Updater.exe" if sys.platform.startswith("win") else "Updater"
            updaterFilePath = os.path.join(appDir, updaterExe)
            updaterFilePathDest = os.path.join(tempdir.path(), updaterExe)
            logging.info(f"Copied {updaterFilePath} to {updaterFilePathDest}")
            shutil.copy2(updaterFilePath, updaterFilePathDest)

            logging.debug(f"appDir: {appDir}")

            if self.requiresRoot(appDir):
                errMsg = f"Requires root: {appDir}"
                logging.error(errMsg)
                self.installError(errMsg)
                return

            process: QProcess = QProcess()
            process.setWorkingDirectory(tempdir.path())
            process.setProgram(f".{os.sep}Updater")
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
            if self.worker.success:
                logging.info("Exiting the current application instance after successful update...")
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

    @Slot()
    def workerProxyRequestSlot(self):
        logging.info("Update worker needs auth.")
        self.proxyAuthRequiredUpdater.emit()

    @Slot(str, str)
    def setProxyCredentials(self, username: str, password: str):
        logging.info("Set proxy credentials")
        self.proxyUsername = username
        self.proxyPassword = password
        self.workerSetProxyCredentialsSignal.emit(username, password)

    def setProxy(self):
        enabled = self.settings.value("proxy/enabled", False, type=bool)
        if enabled:
            host = self.settings.value("proxy/host", "", type=str)
            port = self.settings.value("proxy/port", 8080, type=int)
            logging.info(f"Set proxy: {host}:{port}")
            self.proxy = QNetworkProxy(QNetworkProxy.HttpProxy, host, port)
            if self.proxyUsername != "":
                self.proxy.setUser(self.proxyUsername)
            if self.proxyPassword != "":
                self.proxy.setPassword(self.proxyPassword)
            self.manager.setProxy(self.proxy)
        else:
            logging.info("Clear proxy")
            self.manager.setProxy(QNetworkProxy(QNetworkProxy.NoProxy))

    @Slot()
    def checkForUpdate(self):
        logging.info(f"Check for updates: {self.latestBuildUrl.toString()}")

        self.setProxy()

        req = QNetworkRequest(self.latestBuildUrl)
        reply = self.manager.get(req)
        reply.finished.connect(lambda: self.checkForUpdateRequestFinished(reply))

    @Slot(QNetworkReply)
    def checkForUpdateRequestFinished(self, reply):

        if reply.error() != QNetworkReply.NetworkError.NoError:
            logging.error(f"Network error: {reply.errorString()}")
            self.newBuildError.emit()

            if reply.error() == QNetworkReply.NetworkError.ProxyAuthenticationRequiredError:
                logging.warning("Proxy authentication required")
                self.proxyAuthRequired.emit()

            reply.deleteLater()
            return

        try:
            body = bytes(reply.readAll()).decode(errors="ignore")
            data = json.loads(body)
            logging.debug(f"Fetched builds: {json.dumps(data)}")
            if "value" in data and len(data["value"]) > 0:
                latestBuild = data["value"][0]
                latestBuildId = str(latestBuild.get("id", ""))

            if (int(latestBuildId) > int(self.currentBuildId)) or (self.currentBranch != self.masterBranch):
                logging.info(f"New update available, build id: {latestBuildId}")
                self.newBuildFound.emit(latestBuildId)
            else:
                logging.info("No new update available")
                self.newBuildFound.emit("")
        except Exception as e:
            logging.error(f"Failed in update check: {e}")
            self.newBuildError.emit()

        reply.deleteLater()
