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
from PySide6.QtCore import QThread
from cyclonedds import core, builtin
from cyclonedds.util import duration
from dds_access.domain_participant_factory import DomainParticipantFactory
from PySide6.QtCore import Signal
import time


class DomainFinder(QThread):

    foundDomainSignal = Signal(int, bool)

    def __init__(self, domain_id: int):
        super().__init__()
        self.domain_id = domain_id
        self.guardCondition = None
        self.scan_seconds = 5
        self.stopRequested = False

    def stop(self):
        self.stopRequested = True
        if self.guardCondition is not None:
            try:
                self.guardCondition.set(False)
            except:
                pass

    def run(self):
        logging.debug(f"domain_finder({self.domain_id}) ...")

        try:
            with DomainParticipantFactory.get_participant(self.domain_id) as domain_participant:

                waitset = core.WaitSet(domain_participant)                

                self.guardCondition = core.GuardCondition(domain_participant)
                waitset.attach(self.guardCondition)

                rdp = builtin.BuiltinDataReader(domain_participant, builtin.BuiltinTopicDcpsParticipant)
                rcp = core.ReadCondition(rdp, core.SampleState.Any | core.ViewState.Any | core.InstanceState.Any)
                waitset.attach(rcp)

                start_time = time.monotonic()
                while time.monotonic() - start_time < self.scan_seconds and not self.stopRequested:
                    try:
                        amount_triggered = waitset.wait(duration(seconds=1))
                    except:
                        pass
                    if amount_triggered > 0:
                        for p in rdp.take(condition=rcp):
                            if p.sample_info.sample_state == core.SampleState.NotRead and p.sample_info.instance_state == core.InstanceState.Alive:
                                if p.key != domain_participant.get_guid():
                                    logging.info(f"detected participant on domain {self.domain_id}")
                                    self.foundDomainSignal.emit(self.domain_id, True)
                                    return

        except Exception as e:
            logging.error(f"Domain: {str(self.domain_id)} {str(e)}")

        self.foundDomainSignal.emit(self.domain_id, False)
