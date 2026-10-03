"""Select the DDS configuration before creating any participant."""
import os
from pathlib import Path
from urllib.parse import unquote
from xml.etree import ElementTree as ET
from PySide6.QtCore import QObject, Property, QSettings, QUrl, Signal, Slot
from PySide6.QtNetwork import QNetworkInterface

DEFAULT_XML = """<CycloneDDS>
  <Domain Id="any">
    <Discovery>
      <ParticipantIndex>auto</ParticipantIndex>
    </Discovery>
  </Domain>
</CycloneDDS>
"""


def validate_xml(xml):
    root = ET.fromstring(xml)
    if root.tag.split("}")[-1] != "CycloneDDS":
        raise ValueError("The XML root must be CycloneDDS.")


def file_path(uri):
    if uri.lower().startswith("file://"):
        path = uri[7:].lstrip("/")
        if path[1:2] == ":":
            return unquote(path)
    url = QUrl(uri)
    return url.toLocalFile() if url.isLocalFile() else uri


def describe_uri(uri):
    if not uri:
        return "Cyclone DDS defaults (CYCLONEDDS_URI is not set)"
    if uri.lstrip().startswith("<"):
        return "Inline XML"
    return uri


class DdsConfigModel(QObject):
    changed = Signal()
    networkInterfacesChanged = Signal()
    XML_KEY = "dds/configXml"
    ENABLED_KEY = "dds/useSavedConfiguration"
    SOURCE_NAMES = {"environment": "CYCLONEDDS_URI environment", "xml": "Configuration saved in Insight"}

    def __init__(self, settings=None, environ=None, parent=None):
        super().__init__(parent)
        self.settings = settings if settings is not None else QSettings(self)
        self._shutting_down = False
        self._network_interfaces_text = ""
        self._network_interfaces = []
        self.environ = environ if environ is not None else os.environ
        self._startup_uri = self.environ.get("CYCLONEDDS_URI", "")
        self._source = "xml" if self.settings.value(self.ENABLED_KEY, False, type=bool) else "environment"
        self._editor_xml = self.settings.value(self.XML_KEY, DEFAULT_XML, type=str)
        self._status = ""
        self._active_source = "environment"
        try:
            if self._source == "xml":
                validate_xml(self._editor_xml)
                self.environ["CYCLONEDDS_URI"] = self._editor_xml
                self._active_source = "xml"
            preview = self._startup_uri
            if self._source != "xml" and preview and not self.settings.contains(self.XML_KEY):
                self._editor_xml = preview if preview.lstrip().startswith("<") else Path(file_path(preview)).read_text(encoding="utf-8")
        except (OSError, ValueError, ET.ParseError) as error:
            self._status = f"Configuration not applied or preview unavailable: {error}"
        self._active_uri = self.environ.get("CYCLONEDDS_URI", "")
        self._initial_choice = self._choice()

    @Property(str, notify=networkInterfacesChanged)
    def networkInterfacesText(self):
        return self._network_interfaces_text

    @Property("QVariantList", notify=networkInterfacesChanged)
    def networkInterfaces(self):
        return self._network_interfaces

    @Slot()
    def refreshNetworkInterfaces(self):
        interfaces = sorted(QNetworkInterface.allInterfaces(), key=lambda interface: (
            not bool(interface.flags() & QNetworkInterface.IsUp),
            bool(interface.flags() & QNetworkInterface.IsLoopBack),
            interface.name(),
        ))
        lines = []
        rows = []
        for interface in interfaces:
            addresses = list(dict.fromkeys(
                entry.ip().toString() for entry in interface.addressEntries()
                if not entry.ip().isNull()))
            if not addresses:
                continue
            name = interface.name()
            display_name = interface.humanReadableName()
            lines.append(f"{name} ({display_name})" if display_name and display_name != name else name)
            rows.append({"name": name, "displayName": display_name, "addresses": addresses})
            lines.extend(f"    {address}" for address in addresses)
        self._network_interfaces = rows
        self._network_interfaces_text = "\n".join(lines)
        self.networkInterfacesChanged.emit()

    @Slot()
    def shutdown(self):
        self._shutting_down = True
        self.settings.sync()

    @Property(str, constant=True)
    def settingsFile(self):
        return self.settings.fileName()

    @Property(bool, constant=True)
    def settingsFileAvailable(self):
        # Native QSettings on Windows uses the registry, not a file.
        return not (os.name == "nt" and self.settings.format() == QSettings.NativeFormat)

    @Slot(result=bool)
    def openSettingsFile(self):
        if self._shutting_down or not self.settingsFileAvailable:
            return False
        from PySide6.QtGui import QDesktopServices
        self.settings.sync()
        return QDesktopServices.openUrl(QUrl.fromLocalFile(self.settings.fileName()))

    def _choice(self):
        return (self._source, self._editor_xml if self._source == "xml" else "")

    @Property(str, notify=changed)
    def editorXml(self):
        return self._editor_xml

    @Property(str, constant=True)
    def activeUri(self):
        return self._active_uri or "<not set>"

    @Property(str, constant=True)
    def activeSummary(self):
        return self.SOURCE_NAMES[self._active_source] + " — " + describe_uri(self._active_uri)

    @Property(str, constant=True)
    def startupUri(self):
        return self._startup_uri

    @Property(str, constant=True)
    def startupSummary(self):
        return describe_uri(self._startup_uri)

    @Property(str, notify=changed)
    def selectedSource(self):
        return self._source

    @Property(str, notify=changed)
    def nextSummary(self):
        uri = self._editor_xml if self._source == "xml" else self._startup_uri
        return self.SOURCE_NAMES[self._source] + " — " + describe_uri(uri)

    @Property(str, notify=changed)
    def status(self):
        return self._status

    @Property(bool, notify=changed)
    def restartRequired(self):
        return self._choice() != self._initial_choice

    def _persist(self, source, value=""):
        if self._shutting_down:
            return False
        self.settings.setValue(self.ENABLED_KEY, source == "xml")
        if source == "xml":
            self.settings.setValue(self.XML_KEY, value)
        self.settings.sync()
        if self.settings.status() != QSettings.NoError:
            self._status = "Could not save the configuration. Check storage permissions."
            self.changed.emit()
            return False
        self._source = source
        if source == "xml":
            self._editor_xml = value
        self._status = "Saved. Restart required." if self.restartRequired else "Selection saved."
        self.changed.emit()
        return True

    @Slot(str, result=bool)
    def save(self, xml):
        try:
            validate_xml(xml)
        except (ValueError, ET.ParseError) as error:
            self._status = f"Not saved: {error}"
            self.changed.emit()
            return False
        return self._persist("xml", xml)

    @Property(bool, notify=changed)
    def editorWritable(self):
        return self._source == "xml" or bool(self._startup_uri and not self._startup_uri.lstrip().startswith("<") and Path(file_path(self._startup_uri)).is_file())

    @Slot(result=str)
    def reloadEditor(self):
        if self._source == "environment" and self._startup_uri:
            try:
                self._editor_xml = self._startup_uri if self._startup_uri.lstrip().startswith("<") else Path(file_path(self._startup_uri)).read_text(encoding="utf-8")
            except (OSError, ValueError) as error:
                self._status = f"Cannot reload: {error}"
                self.changed.emit()
        return self._editor_xml

    @Slot(str, result=bool)
    def saveEditor(self, xml):
        if self._shutting_down:
            return False
        if self._source == "xml":
            return self.save(xml)
        if not self.editorWritable:
            return False
        try:
            validate_xml(xml)
            Path(file_path(self._startup_uri)).write_text(xml, encoding="utf-8")
        except (OSError, ValueError, ET.ParseError) as error:
            self._status = f"Not saved: {error}"
            self.changed.emit()
            return False
        self._editor_xml = xml
        self._status = "Saved. Restart required."
        self.changed.emit()
        return True

    @Slot(result=bool)
    def useManagedConfiguration(self):
        return self.save(self.settings.value(self.XML_KEY, self._editor_xml, type=str))

    @Slot()
    def useStartupConfiguration(self):
        self._persist("environment")
