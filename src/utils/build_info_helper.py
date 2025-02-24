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


def getBuildInfoGitHashShort() -> str:
    try:
        from build_info import CYCLONEDDS_INSIGHT_GIT_HASH_SHORT
        return CYCLONEDDS_INSIGHT_GIT_HASH_SHORT
    except Exception:
        return "n/a"

def getBuildInfoGitHash() -> str:
    try:
        from build_info import CYCLONEDDS_INSIGHT_GIT_HASH
        return CYCLONEDDS_INSIGHT_GIT_HASH
    except Exception:
        return "n/a"

def getBuildInfoGitBranch() -> str:
    try:
        from build_info import CYCLONEDDS_INSIGHT_GIT_BRANCH
        return CYCLONEDDS_INSIGHT_GIT_BRANCH
    except Exception:
        return "n/a"

def getBuildPipelineId() -> str:
    try:
        from build_info import CYCLONEDDS_INSIGHT_BUILD_PIPELINE_ID
        return CYCLONEDDS_INSIGHT_BUILD_PIPELINE_ID
    except Exception:
        return "19"

def getBuildId() -> str:
    try:
        from build_info import CYCLONEDDS_INSIGHT_BUILD_ID
        return CYCLONEDDS_INSIGHT_BUILD_ID
    except Exception:
        return "0"

def getBuildInfoCycloneGitHash() -> str:
    try:
        from build_info import CYCLONEDDS_GIT_HASH
        return CYCLONEDDS_GIT_HASH
    except Exception:
        return "n/a"

def getBuildInfoCycloneGitHashShort() -> str:
    try:
        from build_info import CYCLONEDDS_GIT_HASH_SHORT
        return CYCLONEDDS_GIT_HASH_SHORT
    except Exception:
        return "n/a"

def getBuildInfoCyclonePythonGitHash() -> str:
    try:
        from build_info import CYCLONEDDS_PYTHON_GIT_HASH
        return CYCLONEDDS_PYTHON_GIT_HASH
    except Exception:
        return "n/a"

def getBuildInfoCyclonePythonGitHashShort() -> str:
    try:
        from build_info import CYCLONEDDS_PYTHON_GIT_HASH_SHORT
        return CYCLONEDDS_PYTHON_GIT_HASH_SHORT
    except Exception:
        return "n/a"
