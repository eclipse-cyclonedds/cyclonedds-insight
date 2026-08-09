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

from PySide6.QtCore import (
    Qt,
    QModelIndex,
    QAbstractListModel,
    QByteArray,
    Property,
    QSettings,
)
from PySide6.QtCore import QTranslator
from PySide6.QtCore import QObject, Slot
from loguru import logger as logging


class LanguageModel(QAbstractListModel):

    NameRole = Qt.UserRole + 1
    LanguageSettingKey = "general/language"

    def __init__(self, app, engine, parent=QObject()):
        super().__init__(parent)
        self.app = app
        self.engine = engine
        self.languages = [
            {"code": "en", "name": "English (EN)"},
            {"code": "de", "name": "Deutsch (DE)"},
            {"code": "nl", "name": "Nederlands (NL)"},
            {"code": "fr", "name": "Français (FR)"},
            {"code": "jp", "name": "日本語 (JP)"},
            {"code": "cn", "name": "简体中文 (CN)"},
        ]

        self.settings = QSettings()
        stored_language = self.settings.value(
            self.LanguageSettingKey, "en", type=str)
        self.current_language_index = self._index_for_code(stored_language)

        app.translator = QTranslator()
        self.loadLanguageByIndex(self.current_language_index)

    def _index_for_code(self, language_code: str) -> int:
        for index, language in enumerate(self.languages):
            if language["code"] == language_code:
                return index
        return 0

    @Property(int, constant=True)
    def currentLanguageIndex(self):
        return self.current_language_index

    def data(self, index: QModelIndex, role: int = Qt.DisplayRole):
        if not index.isValid():
            return None
        row = index.row()

        if role == self.NameRole or role == Qt.DisplayRole:
            return self.languages[row]["name"]
        
        return None

    def roleNames(self) -> dict[int, QByteArray]:
        return {
            self.NameRole: b'name'
        }

    def rowCount(self, index: QModelIndex = QModelIndex()) -> int:
        return len(self.languages)

    @Slot(int)
    def loadLanguageByIndex(self, index):
        if 0 <= index < len(self.languages):
            language_code = self.languages[index]["code"]
            if self.loadLanguage(language_code):
                self.current_language_index = index
                self.settings.setValue(self.LanguageSettingKey, language_code)
                self.settings.sync()

    def loadLanguage(self, languageCode: str):
        qmFile = f":/src/translations/cyclonedds-insight_{languageCode}.qm"
        logging.info(f"Switching language to {languageCode}, loading file: {qmFile}")
        return self.switchLanguage(qmFile)

    def switchLanguage(self, qm_file):

        self.app.removeTranslator(self.app.translator)

        ok = self.app.translator.load(qm_file)
        logging.info(f"Loading translation file {qm_file}, success: {ok}")

        if ok:
            self.app.installTranslator(self.app.translator)
            self.engine.retranslate()
        else:
            logging.error(f"Failed to load translation file {qm_file}")

        return ok
