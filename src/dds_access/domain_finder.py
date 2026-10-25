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

from collections import deque
import gc
from threading import Event
import time

from loguru import logger as logging
from PySide6.QtCore import QObject, Property, QThread, QTimer, Qt, Signal, Slot


MAX_SCAN_PARTICIPANTS = 8


class _ParticipantProbe:
    """Independent normal DDS participant; all access stays on the scan thread."""

    def __init__(self, domain):
        from cyclonedds import builtin
        from cyclonedds.domain import DomainParticipant

        self.participant = None
        self.reader = None
        try:
            self.participant = DomainParticipant(domain)
            self.reader = builtin.BuiltinDataReader(self.participant, builtin.BuiltinTopicDcpsParticipant)
        except Exception:
            self.close()
            raise

    def poll(self):
        from cyclonedds.core import InstanceState
        # One foreign participant is enough. Avoid decoding a batch of QoS
        # samples just to discard it immediately after the first discovery.
        return any(sample.key != self.participant.guid and sample.sample_info.valid_data and
                   sample.sample_info.instance_state == InstanceState.Alive
                   for sample in self.reader.take(N=1))

    def close(self):
        # The bindings' reader/read-condition cycle is collected by the scan
        # thread before admitting replacements. Do not patch binding internals.
        self.reader = None
        self.participant = None


class _ScanThread(QThread):
    domainResult = Signal(int, str, str)
    activeChanged = Signal(int)
    pausedChanged = Signal(bool)

    def __init__(self, domains, observation_seconds, max_active, startup_interval_seconds,
                 probe_factory, parent):
        super().__init__(parent)
        self.domains = domains
        self.observation_seconds = observation_seconds
        self.max_active = max_active
        self.startup_interval_seconds = startup_interval_seconds
        self.probe_factory = probe_factory
        self.stop_requested = Event()
        self.pause_requested = Event()
        self.outcome = "complete"
        self._active = {}
        self._errors = set()
        self._peak_active = 0
        self._create_seconds = 0.0
        self._max_create_seconds = 0.0
        self._cleanup_seconds = 0.0
        self._max_cleanup_seconds = 0.0

    def stop(self):
        self.stop_requested.set()

    def _report(self, domain, status, detail=""):
        if status == "error":
            self._errors.add(domain)
        else:
            self._errors.discard(domain)
        self.domainResult.emit(domain, status, detail)

    def _release(self, domains):
        started = time.perf_counter()
        for domain in domains:
            probe, _ = self._active.pop(domain)
            probe.close()
        # BuiltinDataReader retains its ReadCondition, which retains the reader.
        # Release these cycles before the next native participant is created.
        # Remaining live probes stay strongly referenced in _active.
        gc.collect()
        elapsed = time.perf_counter() - started
        self._cleanup_seconds += elapsed
        self._max_cleanup_seconds = max(self._max_cleanup_seconds, elapsed)
        self.activeChanged.emit(len(self._active))

    def _scan(self):
        pending = deque(sorted(self.domains))
        next_start = 0.0
        startup_remaining = self.max_active
        while pending or self._active:
            if self.stop_requested.is_set():
                self.outcome = "cancelled"
                break
            if self.pause_requested.is_set():
                # Release temporary participants before permanent joins. Retry
                # interrupted probes without discarding any finished results.
                interrupted = list(self._active)
                if interrupted:
                    self._release(interrupted)
                    pending.extendleft(reversed(interrupted))
                self.pausedChanged.emit(True)
                while self.pause_requested.is_set() and not self.stop_requested.is_set():
                    self.stop_requested.wait(0.02)
                self.pausedChanged.emit(False)
                continue
            while (pending and len(self._active) < self.max_active
                   and time.monotonic() >= next_start):
                if self.stop_requested.is_set() or self.pause_requested.is_set():
                    break
                domain = pending.popleft()
                # Spread only the initial group. Afterwards free slots are
                # filled immediately, without restarting the startup ramp.
                if startup_remaining:
                    startup_remaining -= 1
                    next_start = (time.monotonic() + self.startup_interval_seconds
                                  if startup_remaining else 0.0)
                started = time.perf_counter()
                try:
                    probe = self.probe_factory(domain)
                    self._active[domain] = (probe, time.monotonic() + self.observation_seconds)
                    self._peak_active = max(self._peak_active, len(self._active))
                    self.activeChanged.emit(len(self._active))
                except Exception as error:
                    self._report(domain, "error", str(error))
                finally:
                    elapsed = time.perf_counter() - started
                    self._create_seconds += elapsed
                    self._max_create_seconds = max(self._max_create_seconds, elapsed)
                # Failed constructors can retain DDS objects in traceback cycles.
                if domain not in self._active:
                    gc.collect()
            released = []
            results = []
            for domain, (probe, deadline) in list(self._active.items()):
                if self.stop_requested.is_set():
                    break
                try:
                    if probe.poll():
                        results.append((domain, "found", ""))
                    elif time.monotonic() >= deadline:
                        results.append((domain, "not_observed", ""))
                    else:
                        continue
                except Exception as error:
                    results.append((domain, "error", str(error)))
                released.append(domain)
            if released:
                self._release(released)
                for result in results:
                    self._report(*result)
            self.stop_requested.wait(0.02)

    def run(self):
        started = time.perf_counter()
        try:
            self._scan()
            if self._errors and self.outcome == "complete":
                self.outcome = "incomplete"
        except Exception as error:
            logging.exception("Domain scan failed")
            self._report(-1, "error", str(error))
            self.outcome = "incomplete"
        finally:
            if self._active:
                self._release(list(self._active))
            if self.stop_requested.is_set():
                self.outcome = "cancelled"
            logging.info("Domain scan: state={}, elapsed={:.2f}s, peak probes={}, "
                         "participant creation total/max={:.2f}/{:.2f}s, "
                         "cleanup total/max={:.2f}/{:.2f}s",
                         self.outcome, time.perf_counter() - started, self._peak_active,
                         self._create_seconds, self._max_create_seconds,
                         self._cleanup_seconds, self._max_cleanup_seconds)


class DomainScanner(QObject):
    """One background thread, bounded rolling DDS probes, no child processes."""

    changed = Signal()
    elapsedChanged = Signal()
    foundDomain = Signal(int)
    finished = Signal()
    pausedChanged = Signal(bool)

    def __init__(self, parent=None, *, domains=None, observation_seconds=3.8,
                 max_active=MAX_SCAN_PARTICIPANTS, startup_interval_seconds=1.0,
                 probe_factory=None):
        super().__init__(parent)
        self.domains = list(range(233)) if domains is None else sorted(set(domains))
        self.observation_seconds = observation_seconds
        self.max_active = max(1, min(MAX_SCAN_PARTICIPANTS, max_active))
        self.startup_interval_seconds = max(0.0, startup_interval_seconds)
        self.probe_factory = probe_factory or _ParticipantProbe
        self._thread = None
        self._running = False
        self._paused = False
        self._resuming = False
        self._pause_after_resume = False
        self._state = "idle"
        self._found = set()
        self._joined = set()
        self._errors = {}
        self._total = len(self.domains)
        self._progress = 0
        self._completed_domains = set()
        self._active_count = 0
        self._scan_started_at = None
        self._elapsed_seconds = 0
        self._elapsed_timer = QTimer(self)
        self._elapsed_timer.setInterval(1000)
        self._elapsed_timer.timeout.connect(self._update_elapsed)

    running = Property(bool, lambda self: self._running, notify=changed)
    paused = Property(bool, lambda self: self._paused, notify=changed)
    state = Property(str, lambda self: self._state, notify=changed)
    completed = Property(int, lambda self: self._progress, notify=changed)
    total = Property(int, lambda self: self._total, notify=changed)
    foundCount = Property(int, lambda self: len(self._found - self._joined), notify=changed)
    errorCount = Property(int, lambda self: len(self._errors), notify=changed)
    activeCount = Property(int, lambda self: self._active_count, notify=changed)
    elapsedSeconds = Property(int, lambda self: self._elapsed_seconds, notify=elapsedChanged)
    candidateDomains = Property("QVariantList", lambda self: sorted(self._found - self._joined), notify=changed)
    joinedCount = Property(int, lambda self: len(self._joined), notify=changed)
    joinedDomains = Property("QVariantList", lambda self: sorted(self._joined), notify=changed)
    resultDomains = Property("QVariantList", lambda self: [
        {"domainId": domain, "joined": domain in self._joined}
        for domain in sorted(self._found | self._joined)], notify=changed)
    errorDetails = Property(str, lambda self: self.error_details(), notify=changed)

    def mark_joined(self, domain, joined=True):
        if joined:
            self._joined.add(domain)
            if domain in self.domains:
                self._completed_domains.add(domain)
                self._progress = len(self._completed_domains)
        else:
            self._joined.discard(domain)
            if self._state == "idle":
                self._completed_domains.discard(domain)
                self._progress = len(self._completed_domains)
        self.changed.emit()

    def error_details(self):
        return "\n".join(f"{domain}: {detail}" for domain, detail in sorted(self._errors.items()))

    def start(self, excluded=()):
        if self._thread is not None:
            return
        self._joined = set(excluded)
        domains = [domain for domain in self.domains if domain not in self._joined]
        self._total = len(self.domains)
        self._completed_domains = self._joined.intersection(self.domains)
        self._progress = len(self._completed_domains)
        self._found.clear()
        self._errors.clear()
        self._active_count = 0
        self._state = "running"
        self._running = True
        self._scan_started_at = time.monotonic()
        self._elapsed_seconds = 0
        self.elapsedChanged.emit()
        self._elapsed_timer.start()
        thread = _ScanThread(domains, self.observation_seconds,
                             self.max_active, self.startup_interval_seconds, self.probe_factory,
                             self)
        self._thread = thread
        thread.domainResult.connect(self._result, Qt.ConnectionType.QueuedConnection)
        thread.activeChanged.connect(self._set_active, Qt.ConnectionType.QueuedConnection)
        thread.pausedChanged.connect(self._set_paused, Qt.ConnectionType.QueuedConnection)
        thread.finished.connect(self._thread_finished, Qt.ConnectionType.QueuedConnection)
        self.changed.emit()
        thread.start()

    def pause(self):
        if self._thread is not None:
            if self._resuming:
                self._pause_after_resume = True
            else:
                self._thread.pause_requested.set()

    def resume(self):
        if self._thread is not None:
            self._resuming = self._paused
            self._thread.pause_requested.clear()

    @Slot(bool)
    def _set_paused(self, paused):
        self._paused = paused
        if not paused:
            self._resuming = False
            if self._pause_after_resume:
                self._pause_after_resume = False
                self.pause()
        self.changed.emit()
        self.pausedChanged.emit(paused)

    @Slot(int)
    def _set_active(self, count):
        self._active_count = count
        self.changed.emit()

    @Slot(int, str, str)
    def _result(self, domain, status, detail):
        # Each domain has one observation window and one final result.
        if domain >= 0:
            self._completed_domains.add(domain)
            self._progress = len(self._completed_domains)
        self._errors.pop(domain, None)
        if status == "found":
            self._found.add(domain)
            self.foundDomain.emit(domain)
        elif status == "error":
            self._errors[domain] = detail
        self.changed.emit()

    @Slot()
    def _update_elapsed(self):
        if self._scan_started_at is not None:
            elapsed = int(time.monotonic() - self._scan_started_at)
            if elapsed != self._elapsed_seconds:
                self._elapsed_seconds = elapsed
                self.elapsedChanged.emit()

    @Slot()
    def _thread_finished(self):
        thread = self._thread
        if thread is None:
            return
        self._update_elapsed()
        self._elapsed_timer.stop()
        self._scan_started_at = None
        self._thread = None
        self._active_count = 0
        self._paused = False
        self._resuming = False
        self._pause_after_resume = False
        self._running = False
        self._state = thread.outcome
        thread.deleteLater()
        self.changed.emit()
        self.finished.emit()

    @Slot()
    def cancel(self):
        if self._thread is not None:
            self._state = "cancelled"
            self._thread.stop()
            self.changed.emit()

    def shutdown(self):
        # After app.exec(): cooperatively stop and join. Never terminate a native
        # DDS call or destroy a running QThread to force a time limit.
        self.cancel()
        if self._thread is not None:
            self._thread.wait()
            self._thread_finished()
