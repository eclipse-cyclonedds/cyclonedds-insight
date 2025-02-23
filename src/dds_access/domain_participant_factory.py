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

from loguru import logger as logging
from cyclonedds import domain


class DomainParticipantFactory:
    _participants = {}
    _ref_count = {}

    @classmethod
    def get_participant(cls, domain_id):
        if domain_id not in cls._participants:
            # Create a new participant and initialize reference count
            logging.info(f"Creating participant for domain {domain_id}")
            cls._participants[domain_id] = domain.DomainParticipant(domain_id)
            cls._ref_count[domain_id] = 1
        else:
            # Increment reference count for existing participant
            cls._ref_count[domain_id] += 1
        return cls._RAIIWrapper(cls, domain_id)

    class _RAIIWrapper:
        def __init__(self, factory, domain_id):
            self._factory = factory
            self._domain_id = domain_id

        def __enter__(self):
            return self._factory._participants[self._domain_id]

        def __exit__(self, exc_type, exc_value, traceback):
            # Decrease the reference count and clean up if no more references
            self._factory._ref_count[self._domain_id] -= 1
            if self._factory._ref_count[self._domain_id] == 0:
                logging.info(f"Cleaning up participant for domain {self._domain_id}")
                # Delete the participant and its reference count
                del self._factory._participants[self._domain_id]
                del self._factory._ref_count[self._domain_id]
