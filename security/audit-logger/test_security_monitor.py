import importlib.util
import json
import os
from pathlib import Path
import tempfile
import unittest

MODULE_PATH = Path(__file__).with_name("security-monitor.py")
SPEC = importlib.util.spec_from_file_location("security_monitor", MODULE_PATH)
monitor = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(monitor)


class AuditLogRotationTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        root = Path(self.temporary.name)
        self.server_log = root / "latest.log"
        self.audit_log = root / "audit.json"
        self.state_file = root / "state.json"
        monitor.LOG_FILE = str(self.server_log)
        monitor.AUDIT_LOG = str(self.audit_log)
        monitor.STATE_FILE = str(self.state_file)
        monitor.LEGACY_STATE_FILE = str(root / "legacy-state")

    def tearDown(self):
        self.temporary.cleanup()

    def events(self):
        if not self.audit_log.exists():
            return []
        return [json.loads(line) for line in self.audit_log.read_text().splitlines()]

    def test_reads_only_appended_events(self):
        self.server_log.write_text("Alex joined the game\n")
        state = monitor.read_available(monitor.get_state())
        monitor.save_state(state)

        with self.server_log.open("a") as f:
            f.write("Alex left the game\n")
        monitor.read_available(monitor.get_state())

        self.assertEqual(
            [event["event_type"] for event in self.events()],
            ["PLAYER_JOIN", "PLAYER_LEAVE"],
        )

    def test_resets_offset_when_log_is_truncated(self):
        self.server_log.write_text("Alex joined the game\n" + "x" * 100)
        state = monitor.read_available(monitor.get_state())
        monitor.save_state(state)

        self.server_log.write_text("Alex left the game\n")
        monitor.read_available(monitor.get_state())

        self.assertEqual(self.events()[-1]["event_type"], "PLAYER_LEAVE")

    def test_resets_offset_when_log_is_replaced(self):
        self.server_log.write_text("Alex joined the game\n")
        state = monitor.read_available(monitor.get_state())
        monitor.save_state(state)

        replacement = self.server_log.with_suffix(".new")
        replacement.write_text("Alex left the game\n" + "x" * 100)
        os.replace(replacement, self.server_log)
        monitor.read_available(monitor.get_state())

        self.assertEqual(self.events()[-1]["event_type"], "PLAYER_LEAVE")

    def test_migrates_integer_state_and_recovers_from_shorter_log(self):
        Path(monitor.LEGACY_STATE_FILE).write_text("3039940")
        self.server_log.write_text("Done (1.23s)! For help, type help\n")

        state = monitor.read_available(monitor.get_state())

        self.assertEqual(self.events()[-1]["event_type"], "SERVER_START")
        self.assertEqual(state["position"], self.server_log.stat().st_size)


if __name__ == "__main__":
    unittest.main()
