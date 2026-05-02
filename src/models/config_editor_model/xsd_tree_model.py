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

from io import BytesIO
import re, html
from xml.etree import ElementTree as ET
from PySide6.QtCore import Qt, QModelIndex, QAbstractItemModel, QByteArray, Slot, QFile, QIODevice


XS = "{http://www.w3.org/2001/XMLSchema}"


class Node:
    def __init__(self, name, kind="element", details="", parent=None):
        self.name = name
        self.kind = kind
        self.details = details
        self.parent = parent
        self.children = []

    def add(self, node):
        node.parent = self
        self.children.append(node)
        return node

    @property
    def path(self):
        parts = []
        node = self
        while node and node.parent:
            parts.append(node.name)
            node = node.parent
        return "/" + "/".join(reversed(parts))


def clean_doc(text):
    if not text:
        return ""
    text = html.unescape(text)
    text = re.sub(r"<br\s*/?>", "\n", text)
    text = re.sub(r"</p\s*>", "\n\n", text)
    text = re.sub(r"<[^>]+>", "", text)
    return text.strip()


def local_name(qname):
    if not qname:
        return ""
    return qname.split(":")[-1]


def documentation(elem):
    doc = elem.find(f"{XS}annotation/{XS}documentation")
    return clean_doc(doc.text if doc is not None else "")


def enums_or_patterns(elem):
    values = []

    for enum in elem.findall(f".//{XS}enumeration"):
        values.append(f"enum: {enum.get('value')}")

    for pat in elem.findall(f".//{XS}pattern"):
        values.append(f"pattern: {pat.get('value')}")

    return values


def parse_xsd(path):
    if path.startswith("qrc:/"):
        path = ":" + path[4:]

    if path.startswith(":/"):
        file = QFile(path)
        if not file.open(QIODevice.ReadOnly):
            raise RuntimeError(f"Could not open resource: {path}")

        data = bytes(file.readAll())
        file.close()

        tree = ET.parse(BytesIO(data))
    else:
        tree = ET.parse(path)

    root = tree.getroot()

    globals_by_name = {}
    for elem in root.findall(f"{XS}element"):
        name = elem.get("name")
        if name:
            globals_by_name[name] = elem

    root_node = Node("XSD schema", "schema", f"Namespace: {root.get('targetNamespace', '')}")

    visited_stack = set()

    def build_element(xsd_elem, parent, label=None):
        ref = xsd_elem.get("ref")

        if ref:
            target_name = local_name(ref)
            resolved_elem = globals_by_name.get(target_name, xsd_elem)
            name = target_name
        else:
            resolved_elem = xsd_elem
            name = label or xsd_elem.get("name") or "(element)"

        typ = resolved_elem.get("type", "") or xsd_elem.get("type", "")

        lines = [
            f"Path: {parent.path}/{name}\n",
            f"Name: {name}",
            "Kind: element",
        ]

        if typ:
            lines.append(f"Type: {typ}")

        if xsd_elem.get("minOccurs") is not None:
            lines.append(f"minOccurs: {xsd_elem.get('minOccurs')}")
        if xsd_elem.get("maxOccurs") is not None:
            lines.append(f"maxOccurs: {xsd_elem.get('maxOccurs')}")

        doc = documentation(resolved_elem)
        if doc:
            lines.append("\nDocumentation:\n" + doc)

        constraints = enums_or_patterns(resolved_elem)
        if constraints:
            lines.append("\nAllowed values / constraints:\n" + "\n".join(constraints))

        node = parent.add(Node(name, "element", "\n".join(lines)))

        if ref:
            if resolved_elem is not xsd_elem and name not in visited_stack:
                visited_stack.add(name)
                build_contents(resolved_elem, node)
                visited_stack.remove(name)
            return node

        build_contents(resolved_elem, node)
        return node

    def build_attribute(attr, parent):
        name = attr.get("name", "(attribute)")

        lines = [
            f"Path: {parent.path}/@{name}\n",
            f"Name: {name}",
            "Kind: attribute",
        ]

        if attr.get("type"):
            lines.append(f"Type: {attr.get('type')}")
        if attr.get("use"):
            lines.append(f"Use: {attr.get('use')}")

        doc = documentation(attr)
        if doc:
            lines.append("\nDocumentation:\n" + doc)
        else:
            lines.append("\nDocumentation:\n(no documentation found)")

        constraints = enums_or_patterns(attr)
        if constraints:
            lines.append("\nAllowed values / constraints:\n" + "\n".join(constraints))

        parent.add(Node("@" + name, "attribute", "\n".join(lines)))

    def build_contents(xsd_elem, parent):
        for attr in xsd_elem.findall(f".//{XS}attribute"):
            if attr.get("name"):
                build_attribute(attr, parent)

        child_paths = [
            f".//{XS}complexType/{XS}sequence/{XS}element",
            f".//{XS}complexType/{XS}all/{XS}element",
            f".//{XS}complexType/{XS}choice/{XS}element",
        ]

        seen = set()
        for path_expr in child_paths:
            for child in xsd_elem.findall(path_expr):
                key = child.get("name") or child.get("ref")
                if not key or key in seen:
                    continue
                seen.add(key)
                build_element(child, parent)

    start = globals_by_name.get("CycloneDDS")
    if start is not None:
        visited_stack.add("CycloneDDS")
        build_element(start, root_node)
    else:
        for elem in globals_by_name.values():
            build_element(elem, root_node)

    return root_node


class XsdTreeModel(QAbstractItemModel):
    DisplayRole = Qt.DisplayRole
    DetailsRole = Qt.UserRole + 1
    KindRole = Qt.UserRole + 2
    PathRole = Qt.UserRole + 3

    def __init__(self, root):
        super().__init__()
        self.root = root

    def roleNames(self):
        return {
            self.DisplayRole: QByteArray(b"display"),
            self.DetailsRole: QByteArray(b"details"),
            self.KindRole: QByteArray(b"kind"),
        self.PathRole: QByteArray(b"path"),
        }

    def index(self, row, column, parent=QModelIndex()):
        parent_node = parent.internalPointer() if parent.isValid() else self.root
        if 0 <= row < len(parent_node.children):
            return self.createIndex(row, column, parent_node.children[row])
        return QModelIndex()

    def parent(self, index):
        if not index.isValid():
            return QModelIndex()

        node = index.internalPointer()
        parent = node.parent

        if parent is None or parent == self.root:
            return QModelIndex()

        grand = parent.parent or self.root
        row = grand.children.index(parent)
        return self.createIndex(row, 0, parent)

    def rowCount(self, parent=QModelIndex()):
        node = parent.internalPointer() if parent.isValid() else self.root
        return len(node.children)

    def columnCount(self, parent=QModelIndex()):
        return 1

    def data(self, index, role=Qt.DisplayRole):
        if not index.isValid():
            return None

        node = index.internalPointer()

        if role == self.DisplayRole:
            return node.name
        if role == self.DetailsRole:
            return node.details
        if role == self.KindRole:
            return node.kind
        if role == self.PathRole:
            return node.path
        return None

    @Slot(QModelIndex, result=str)
    def detailsAt(self, index):
        if not index.isValid():
            return ""
        return index.internalPointer().details

    @Slot(QModelIndex, result=str)
    def pathAt(self, index):
        if not index.isValid():
            return ""
        return index.internalPointer().path
