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

from PySide6.QtCore import QDir
from loguru import logger as logging
import requests
import json


def delete_folder(folder_path):
    dir = QDir(folder_path)
    if dir.exists():
        success = dir.removeRecursively()
        if success:
            logging.info(f"Successfully deleted folder: {folder_path}")
        else:
            logging.error(f"Failed to delete folder: {folder_path}")
    else:
        logging.error(f"Folder does not exist: {folder_path}")

def download_json(url):
    try:
        response = requests.get(url)
        response.raise_for_status()
        parsed_json = response.json()
        print("Received JSON:", json.dumps(parsed_json, indent=4))
        return parsed_json
    except requests.exceptions.RequestException as e:
        print("HTTP Request failed:", e)
    except json.JSONDecodeError as e:
        print("Invalid JSON received:", e)
    return None
