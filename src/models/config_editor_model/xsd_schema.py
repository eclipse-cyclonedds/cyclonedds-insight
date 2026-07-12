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

from io import BytesIO
import html
import re
from xml.etree import ElementTree as ET

from PySide6.QtCore import QFile, QIODevice


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


class XsdSchema:
    def __init__(self, root, root_elements, children, documentation):
        self.root = root
        self.root_elements = root_elements
        self.children = children
        self.documentation = documentation


def clean_doc(text):
    if not text:
        return ""
    text = html.unescape(text)
    text = re.sub(r"<br\s*/?>", "\n", text)
    text = re.sub(r"</p\s*>", "\n\n", text)
    text = re.sub(r"<[^>]+>", "", text)
    return text.strip()


def local_name(qname):
    return qname.split(":")[-1] if qname else ""


def documentation(element):
    doc = element.find(f"{XS}annotation/{XS}documentation")
    return clean_doc(doc.text if doc is not None else "")


def enums_or_patterns(element):
    values = []
    for enum in element.findall(f".//{XS}enumeration"):
        values.append(f"enum: {enum.get('value')}")
    for pattern in element.findall(f".//{XS}pattern"):
        values.append(f"pattern: {pattern.get('value')}")
    return values


def _load_xsd(path):
    if path.startswith("qrc:/"):
        path = ":" + path[4:]

    if path.startswith(":/"):
        file = QFile(path)
        if not file.open(QIODevice.ReadOnly):
            raise RuntimeError(f"Could not open resource: {path}")
        data = bytes(file.readAll())
        file.close()
        return ET.parse(BytesIO(data)).getroot()

    return ET.parse(path).getroot()


def parse_xsd_schema(path):
    xsd_root = _load_xsd(path)
    globals_by_name = {
        element.get("name"): element
        for element in xsd_root.findall(f"{XS}element")
        if element.get("name")
    }
    root_elements = (["CycloneDDS"] if "CycloneDDS" in globals_by_name
                     else sorted(globals_by_name))
    root_node = Node(
        "XSD schema",
        "schema",
        f"Namespace: {xsd_root.get('targetNamespace', '')}",
    )
    children_by_name = {}
    documentation_by_name = {}
    visited_stack = set()

    def build_attribute(attribute, parent):
        name = attribute.get("name", "(attribute)")
        lines = [
            f"Path: {parent.path}/@{name}\n",
            f"Name: {name}",
            "Kind: attribute",
        ]
        if attribute.get("type"):
            lines.append(f"Type: {attribute.get('type')}")
        if attribute.get("use"):
            lines.append(f"Use: {attribute.get('use')}")

        doc = documentation(attribute)
        lines.append("\nDocumentation:\n" + (doc or "(no documentation found)"))
        constraints = enums_or_patterns(attribute)
        if constraints:
            lines.append("\nAllowed values / constraints:\n"
                         + "\n".join(constraints))
        parent.add(Node("@" + name, "attribute", "\n".join(lines)))

    def build_contents(element, parent, element_name):
        attribute_paths = (
            f"{XS}complexType/{XS}attribute",
            f"{XS}complexType/{XS}simpleContent/{XS}extension/{XS}attribute",
        )
        seen_attributes = set()
        for attribute_path in attribute_paths:
            for attribute in element.findall(attribute_path):
                name = attribute.get("name")
                if name and name not in seen_attributes:
                    seen_attributes.add(name)
                    build_attribute(attribute, parent)

        child_paths = (
            f"{XS}complexType/{XS}sequence/{XS}element",
            f"{XS}complexType/{XS}all/{XS}element",
            f"{XS}complexType/{XS}choice/{XS}element",
        )
        child_names = []
        for child_path in child_paths:
            for child in element.findall(child_path):
                name = local_name(child.get("ref")) or child.get("name")
                if not name or name in child_names:
                    continue
                child_names.append(name)
                build_element(child, parent, name)
        children_by_name[element_name] = child_names

    def build_element(xsd_element, parent, fallback_name=None):
        reference = xsd_element.get("ref")
        name = (local_name(reference) or xsd_element.get("name")
                or fallback_name or "(element)")
        resolved = (globals_by_name.get(name, xsd_element)
                    if reference else xsd_element)
        element_type = resolved.get("type", "") or xsd_element.get("type", "")
        doc = documentation(resolved)
        documentation_by_name.setdefault(name, doc)

        lines = [
            f"Path: {parent.path}/{name}\n",
            f"Name: {name}",
            "Kind: element",
        ]
        if element_type:
            lines.append(f"Type: {element_type}")
        if xsd_element.get("minOccurs") is not None:
            lines.append(f"minOccurs: {xsd_element.get('minOccurs')}")
        if xsd_element.get("maxOccurs") is not None:
            lines.append(f"maxOccurs: {xsd_element.get('maxOccurs')}")
        if doc:
            lines.append("\nDocumentation:\n" + doc)
        constraints = enums_or_patterns(resolved)
        if constraints:
            lines.append("\nAllowed values / constraints:\n"
                         + "\n".join(constraints))

        node = parent.add(Node(name, "element", "\n".join(lines)))
        if name in visited_stack:
            return node

        visited_stack.add(name)
        build_contents(resolved, node, name)
        visited_stack.remove(name)
        return node

    for root_name in root_elements:
        build_element(globals_by_name[root_name], root_node, root_name)

    return XsdSchema(
        root_node,
        root_elements,
        children_by_name,
        documentation_by_name,
    )
