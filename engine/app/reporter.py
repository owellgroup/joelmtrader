"""Pushes engine events to the Spring Boot API (queued, retried, flushable)."""
import logging
import queue
import threading
import time

import requests

from .config import Settings

log = logging.getLogger("reporter")


class Reporter:
    def __init__(self):
        self.q = queue.Queue(maxsize=5000)
        self.pending = 0
        self._lock = threading.Lock()
        threading.Thread(target=self._worker, daemon=True).start()

    def emit(self, type_, data, session_id=None):
        with self._lock:
            self.pending += 1
        try:
            self.q.put_nowait({"type": type_, "sessionId": session_id, "data": data, "ts": int(time.time())})
        except queue.Full:
            with self._lock:
                self.pending -= 1

    def _worker(self):
        while True:
            ev = self.q.get()
            for attempt in range(8):
                try:
                    r = requests.post(Settings.events_url, json=ev, timeout=8,
                                      headers={"X-Internal-Key": Settings.internal_key})
                    if r.status_code < 500:
                        if r.status_code >= 400:
                            log.warning("event %s rejected: %s %s", ev["type"], r.status_code, r.text[:200])
                        break
                except Exception as e:                      # noqa: BLE001
                    log.debug("event push failed (%s): %s", attempt, e)
                time.sleep(min(2 ** attempt, 20))
            with self._lock:
                self.pending -= 1

    def flush(self, timeout=15):
        end = time.time() + timeout
        while self.pending > 0 and time.time() < end:
            time.sleep(0.2)
