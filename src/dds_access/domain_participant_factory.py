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

import logging
from cyclonedds import domain


class DomainParticipantFactory:
    _participants = {}

    @classmethod
    def get_participant(cls, domain_id):
        if domain_id not in cls._participants:
            cls._participants[domain_id] = domain.DomainParticipant(domain_id)
        return cls._participants[domain_id]
