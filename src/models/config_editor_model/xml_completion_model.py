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

import re

from PySide6.QtCore import QObject, Slot


NAME_PATTERN = r"[A-Za-z_][\w:.-]*"


def _local_name(name):
    return name.split(":")[-1] if name else ""


class XmlCompletionModel(QObject):
    """Provides context-aware XML element completions from the CycloneDDS XSD."""

    def __init__(self, schema, parent=None):
        super().__init__(parent)
        self._schema = schema

    @staticmethod
    def _open_element_stack(text):
        stack = []
        tokens = re.finditer(
            rf"<!--.*?-->|<\?.*?\?>|<![^>]*>|</?\s*{NAME_PATTERN}[^>]*>",
            text,
            re.DOTALL,
        )
        for token_match in tokens:
            token = token_match.group(0)
            if token.startswith(("<!--", "<?", "<!")):
                continue

            name_match = re.match(rf"</?\s*({NAME_PATTERN})", token)
            if not name_match:
                continue
            name = _local_name(name_match.group(1))

            if token.startswith("</"):
                for index in range(len(stack) - 1, -1, -1):
                    if stack[index] == name:
                        del stack[index:]
                        break
            elif not token.rstrip().endswith("/>"):
                stack.append(name)

        return stack

    @Slot(str, int, result="QVariantList")
    def suggestions(self, document, cursor_position):
        before_cursor = document[:max(0, cursor_position)]

        closing_match = re.search(rf"</({NAME_PATTERN})?$", before_cursor)
        if closing_match:
            prefix = closing_match.group(1) or ""
            stack = self._open_element_stack(before_cursor[:closing_match.start()])
            if not stack:
                return []
            name = stack[-1]
            if not name.lower().startswith(prefix.lower()):
                return []
            return [{
                "label": f"</{name}>",
                "detail": "Close current element",
                "path": "/" + "/".join(stack),
                "replaceStart": closing_match.start(1)
                                if closing_match.start(1) >= 0
                                else cursor_position,
                "replaceEnd": cursor_position,
                "insertion": f"{name}>",
                "cursorOffset": len(name) + 1,
            }]

        element_match = re.search(rf"<({NAME_PATTERN})?$", before_cursor)
        if not element_match or before_cursor.endswith("</"):
            return []

        prefix = element_match.group(1) or ""
        stack = self._open_element_stack(before_cursor[:element_match.start()])
        candidates = (self._schema.children.get(stack[-1], [])
                      if stack else self._schema.root_elements)
        replace_start = (element_match.start(1)
                         if element_match.start(1) >= 0
                         else cursor_position)

        completions = []
        for name in candidates:
            if not name.lower().startswith(prefix.lower()):
                continue
            insertion = f"{name}></{name}>"
            completions.append({
                "label": name,
                "detail": " ".join(
                    self._schema.documentation.get(name, "").split()),
                "path": "/" + "/".join(stack + [name]),
                "replaceStart": replace_start,
                "replaceEnd": cursor_position,
                "insertion": insertion,
                "cursorOffset": len(name) + 1,
            })

        return completions
