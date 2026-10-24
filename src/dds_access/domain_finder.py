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
from pathlib import Path
from threading import Event
import time

import psutil
from loguru import logger as logging
from PySide6.QtCore import QObject, Property, QThread, Qt, Signal, Slot


def _pids_headroom():
    """Respect visible cgroup v1/v2 task limits, including ancestor limits."""
    available = []
    roots = [Path("/sys/fs/cgroup"), Path("/sys/fs/cgroup/pids")]
    try:
        memberships = Path("/proc/self/cgroup").read_text().splitlines()
    except OSError:
        return None
    for entry in memberships:
        _, controllers, relative = entry.split(":", 2)
        if controllers and "pids" not in controllers.split(","):
            continue
        for root in roots:
            current = root / relative.lstrip("/")
            # In a cgroup namespace the mount root may already be our cgroup.
            candidates = [root]
            while current != root and root in current.parents:
                candidates.append(current)
                current = current.parent
            for directory in candidates:
                try:
                    maximum = (directory / "pids.max").read_text().strip()
                    if maximum != "max":
                        used = int((directory / "pids.current").read_text())
                        available.append(max(0, int(maximum) - used))
                except (OSError, ValueError):
                    continue
    return min(available) if available else None


def _available_probe_slots():
    """Reserve headroom BEFORE native creation, which may abort on exhaustion.

    Measured defaults use six native threads per new domain. Reserve eight per
    probe and sixteen additional tasks for GUI/worker and concurrent activity.
    This is conservative admission control, not recovery from a native abort.
    """
    try:
        process = psutil.Process()
        slots = max(0, (128 - process.num_threads() - 16) // 8)
        pids = _pids_headroom()
        if pids is not None:
            slots = min(slots, max(0, (pids - 16) // 8))
        try:
            import resource
            maximum, _ = resource.getrlimit(resource.RLIMIT_NOFILE)
            if maximum != resource.RLIM_INFINITY:
                slots = min(slots, max(0, (maximum - process.num_fds() - 32) // 8))
        except (ImportError, AttributeError):
            pass
        return min(16, slots)
    except (OSError, psutil.Error):
        # No trustworthy resource information: fail closed rather than trying
        # hundreds of native creations and relying on catchable exceptions.
        return 0


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
        return any(sample.key != self.participant.guid and sample.sample_info.valid_data and
                   sample.sample_info.instance_state == InstanceState.Alive
                   for sample in self.reader.take(N=64))

    def close(self):
        # The bindings' reader/read-condition cycle is collected by the scan
        # thread before admitting replacements. Do not patch binding internals.
        self.reader = None
        self.participant = None


class _ScanThread(QThread):
    phaseStarted = Signal(str)
    domainResult = Signal(int, str, str)
    activeChanged = Signal(int)
    pausedChanged = Signal(bool)

    def __init__(self, domains, quick_seconds, extended_seconds, max_active,
                 probe_factory, capacity, parent):
        super().__init__(parent)
        self.domains = domains
        self.quick_seconds = quick_seconds
        self.extended_seconds = extended_seconds
        self.max_active = max_active
        self.probe_factory = probe_factory
        self.capacity = capacity
        self.stop_requested = Event()
        self.pause_requested = Event()
        self.outcome = "complete"
        self._active = {}
        self._errors = set()

    def stop(self):
        self.stop_requested.set()

    def _report(self, domain, status, detail=""):
        if status == "error":
            self._errors.add(domain)
        else:
            self._errors.discard(domain)
        self.domainResult.emit(domain, status, detail)

    def _release(self, domains):
        for domain in domains:
            probe, _ = self._active.pop(domain)
            probe.close()
        # BuiltinDataReader retains its ReadCondition, which retains the reader.
        # Release these cycles before the next native participant is created.
        # Remaining live probes stay strongly referenced in _active.
        gc.collect()
        self.activeChanged.emit(len(self._active))

    def _pass(self, domains, seconds):
        pending = deque(domains)
        unobserved = []
        stalled = None
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
                stalled = None
                continue
            admitted = False
            while pending and len(self._active) < self.max_active:
                if self.stop_requested.is_set() or self.pause_requested.is_set():
                    break
                if self.capacity() < 1:
                    break
                domain = pending.popleft()
                admitted = True
                try:
                    probe = self.probe_factory(domain)
                    self._active[domain] = (probe, time.monotonic() + seconds)
                    self.activeChanged.emit(len(self._active))
                except Exception as error:
                    self._report(domain, "error", str(error))
                    unobserved.append(domain)
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
                        unobserved.append(domain)
                    else:
                        continue
                except Exception as error:
                    results.append((domain, "error", str(error)))
                    unobserved.append(domain)
                released.append(domain)
            if released:
                self._release(released)
                for result in results:
                    self._report(*result)
            if pending and not self._active and not admitted:
                if stalled is None:
                    stalled = time.monotonic()
                elif time.monotonic() - stalled > 1:
                    for domain in pending:
                        self._report(domain, "error", "RESOURCE_HEADROOM_UNAVAILABLE")
                    unobserved.extend(pending)
                    break
            else:
                stalled = None
            self.stop_requested.wait(0.02)
        return unobserved

    def run(self):
        try:
            self.phaseStarted.emit("quick")
            unobserved = self._pass(self.domains, self.quick_seconds)
            if unobserved and self.outcome == "complete" and not self.stop_requested.is_set():
                self.phaseStarted.emit("extended")
                self._pass(unobserved, self.extended_seconds)
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


class DomainScanner(QObject):
    """One background thread, bounded rolling DDS probes, no child processes."""

    changed = Signal()
    foundDomain = Signal(int)
    finished = Signal()
    pausedChanged = Signal(bool)

    def __init__(self, parent=None, *, domains=None, quick_seconds=0.8,
                 extended_seconds=3.0, max_active=16,
                 probe_factory=None, capacity=None):
        super().__init__(parent)
        self.domains = list(range(233)) if domains is None else list(domains)
        self.quick_seconds = quick_seconds
        self.extended_seconds = extended_seconds
        self.max_active = max(1, min(16, max_active))
        self.probe_factory = probe_factory or _ParticipantProbe
        self.capacity = capacity or _available_probe_slots
        self._thread = None
        self._running = False
        self._paused = False
        self._resuming = False
        self._pause_after_resume = False
        self._state = "idle"
        self._phase = "quick"
        self._found = set()
        self._joined = set()
        self._errors = {}
        self._total = len(self.domains)
        self._progress = 0
        self._completed_domains = set()
        self._active_count = 0

    running = Property(bool, lambda self: self._running, notify=changed)
    paused = Property(bool, lambda self: self._paused, notify=changed)
    state = Property(str, lambda self: self._state, notify=changed)
    phase = Property(str, lambda self: self._phase, notify=changed)
    completed = Property(int, lambda self: self._progress, notify=changed)
    total = Property(int, lambda self: self._total, notify=changed)
    foundCount = Property(int, lambda self: len(self._found - self._joined), notify=changed)
    errorCount = Property(int, lambda self: len(self._errors), notify=changed)
    activeCount = Property(int, lambda self: self._active_count, notify=changed)
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
        self._phase = "quick"
        self._state = "running"
        self._running = True
        thread = _ScanThread(domains, self.quick_seconds, self.extended_seconds,
                             self.max_active, self.probe_factory,
                             self.capacity, self)
        self._thread = thread
        thread.phaseStarted.connect(self._set_phase, Qt.ConnectionType.QueuedConnection)
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

    @Slot(str)
    def _set_phase(self, phase):
        self._phase = phase
        self.changed.emit()

    @Slot(int)
    def _set_active(self, count):
        self._active_count = count
        self.changed.emit()

    @Slot(int, str, str)
    def _result(self, domain, status, detail):
        # A quick negative is still pending its longer observation window.
        # Count each domain only once, when its final result is available.
        if domain >= 0 and (status == "found" or self._phase == "extended"):
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
    def _thread_finished(self):
        thread = self._thread
        if thread is None:
            return
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
