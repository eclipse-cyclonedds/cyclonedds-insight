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

from PySide6.QtCore import Qt, QModelIndex, QAbstractListModel, Qt, QByteArray
from PySide6.QtCore import QTranslator
from PySide6.QtCore import QObject, Slot
from loguru import logger as logging


class LanguageModel(QAbstractListModel):

    NameRole = Qt.UserRole + 1

    def __init__(self, app, engine, parent=QObject()):
        super().__init__(parent)
        self.app = app
        self.engine = engine
        self.languages = ["en", "de"]

        # default language
        app.translator = QTranslator()
        self.loadLanguageByIndex(0)

    def data(self, index: QModelIndex, role: int = Qt.DisplayRole):
        if not index.isValid():
            return None
        row = index.row()

        if role == self.NameRole or role == Qt.DisplayRole:
            return f"{self.languages[row]}"
        
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
            self.loadLanguage(self.languages[index])

    def loadLanguage(self, languageCode: str):
        qmFile = f":/src/translations/cyclonedds-insight_{languageCode}.qm"
        logging.info(f"Switching language to {languageCode}, loading file: {qmFile}")
        self.switchLanguage(qmFile)

    def switchLanguage(self, qm_file):

        self.app.removeTranslator(self.app.translator)

        ok = self.app.translator.load(qm_file)
        logging.info(f"Loading translation file {qm_file}, success: {ok}")

        if ok:
            self.app.installTranslator(self.app.translator)
            self.engine.retranslate()
        else:
            logging.error(f"Failed to load translation file {qm_file}")
