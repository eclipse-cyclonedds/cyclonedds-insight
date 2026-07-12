"""
 * Copyright(c) 2026 Sven Trittler
 *
 * This program and the accompanying materials are made available under the
 * terms of the Eclipse Public License v. 2.0 which is available at
 * http://www.eclipse.org/legal/epl-2.0, or the Eclipse Distribution License
 * v. 1.0 which is available at
 * http://www.eclipse.org/org/documents/edl-v10.php.
 *
 * SPDX-License-Identifier: EPL-2.0 OR BSD-3-Clause
"""

from PySide6.QtCore import QObject, Property, QRegularExpression, Signal
from PySide6.QtGui import QColor, QSyntaxHighlighter, QTextCharFormat
from PySide6.QtQuick import QQuickTextDocument


class XmlSyntaxHighlighter(QSyntaxHighlighter):
    textDocumentChanged = Signal()
    darkModeChanged = Signal()

    COMMENT_STATE = 1

    def __init__(self, parent=None):
        super().__init__(parent)
        self._quick_text_document = None
        self._dark_mode = False
        self._rules = []
        self._comment_start = QRegularExpression(r"<!--")
        self._comment_end = QRegularExpression(r"-->")
        self._update_formats()

    @Property(QObject, notify=textDocumentChanged)
    def textDocument(self):
        return self._quick_text_document

    @textDocument.setter
    def textDocument(self, document):
        if document is self._quick_text_document:
            return

        self._quick_text_document = document
        if isinstance(document, QQuickTextDocument):
            self.setDocument(document.textDocument())
        else:
            self.setDocument(None)
        self.textDocumentChanged.emit()

    @Property(bool, notify=darkModeChanged)
    def darkMode(self):
        return self._dark_mode

    @darkMode.setter
    def darkMode(self, dark_mode):
        if dark_mode == self._dark_mode:
            return

        self._dark_mode = dark_mode
        self._update_formats()
        self.rehighlight()
        self.darkModeChanged.emit()

    @staticmethod
    def _format(color, bold=False, italic=False):
        text_format = QTextCharFormat()
        text_format.setForeground(QColor(color))
        text_format.setFontWeight(700 if bold else 400)
        text_format.setFontItalic(italic)
        return text_format

    def _update_formats(self):
        if self._dark_mode:
            element_color = "#569cd6"
            attribute_color = "#9cdcfe"
            value_color = "#ce9178"
            comment_color = "#6a9955"
            declaration_color = "#c586c0"
            punctuation_color = "#a0a0a0"
        else:
            element_color = "#0000aa"
            attribute_color = "#795e26"
            value_color = "#a31515"
            comment_color = "#008000"
            declaration_color = "#811f8f"
            punctuation_color = "#606060"

        self._element_format = self._format(element_color, bold=True)
        self._attribute_format = self._format(attribute_color)
        self._value_format = self._format(value_color)
        self._comment_format = self._format(comment_color, italic=True)
        self._declaration_format = self._format(declaration_color)
        self._punctuation_format = self._format(punctuation_color)

        self._rules = [
            (QRegularExpression(r"<\?.*?\?>"), self._declaration_format, 0),
            (QRegularExpression(r"</?\s*([A-Za-z_][\w:.-]*)"), self._element_format, 1),
            (QRegularExpression(r"\b([A-Za-z_:][\w:.-]*)(?=\s*=)"), self._attribute_format, 1),
            (QRegularExpression(r"\"[^\"]*\"|'[^']*'"), self._value_format, 0),
            (QRegularExpression(r"</?|/?>"), self._punctuation_format, 0),
        ]

    def highlightBlock(self, text):
        for expression, text_format, capture_group in self._rules:
            matches = expression.globalMatch(text)
            while matches.hasNext():
                match = matches.next()
                start = match.capturedStart(capture_group)
                length = match.capturedLength(capture_group)
                self.setFormat(start, length, text_format)

        self.setCurrentBlockState(0)
        start = 0
        if self.previousBlockState() != self.COMMENT_STATE:
            start = self._comment_start.match(text).capturedStart()

        while start >= 0:
            end_match = self._comment_end.match(text, start)
            end = end_match.capturedStart()
            if end < 0:
                self.setCurrentBlockState(self.COMMENT_STATE)
                length = len(text) - start
            else:
                length = end - start + end_match.capturedLength()

            self.setFormat(start, length, self._comment_format)
            start = self._comment_start.match(text, start + length).capturedStart()
