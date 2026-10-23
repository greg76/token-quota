#!/usr/bin/env python3
"""Check setup and retries without claiming namespaces or installing launchd jobs."""

import contextlib
import importlib.util
import io
import json
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location("setup_collector", Path(__file__).with_name("setup-collector.py"))
setup_collector = importlib.util.module_from_spec(spec)
spec.loader.exec_module(setup_collector)
REAL_RUN = subprocess.run


class SetupTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.project = Path(temporary.name)
        scripts = self.project / "watchface/scripts"
        scripts.mkdir(parents=True)
        shutil.copyfile(setup_collector.PROJECT / "watchface/scripts/generate-settings.py", scripts / "generate-settings.py")
        self.config = self.project / ".local/collector.json"
        self.calls = []
        self.fail_at = None
        self.output = io.StringIO()
        for patcher in [
            patch.object(setup_collector, "PROJECT", self.project),
            patch.object(setup_collector.sys, "platform", "darwin"),
            patch.object(setup_collector.shutil, "which", return_value="/usr/bin/tool"),
            patch.object(setup_collector.subprocess, "run", side_effect=self.run_step),
            contextlib.redirect_stdout(self.output),
        ]:
            patcher.__enter__()
            self.addCleanup(patcher.__exit__, None, None, None)

    def run_step(self, command, **kwargs):
        name = Path(command[1]).name
        self.calls.append(command)
        if name == "collect-quota.py" and "--claim" in command:
            self.config.parent.mkdir(exist_ok=True)
            self.config.write_text(json.dumps({"namespace": command[-1], "path": "data/entry", "key": "local-write-secret"}))
        if name == self.fail_at:
            raise subprocess.CalledProcessError(1, command)
        if name == "generate-settings.py":
            # Run the real generator, with no network or SDK dependency.
            return REAL_RUN(command, capture_output=True, text=True, **kwargs)
        return subprocess.CompletedProcess(command, 0)

    def test_new_setup_claims_and_generates_settings_before_scheduling(self):
        setup_collector.setup()
        config = json.loads(self.config.read_text())
        self.assertTrue(config["namespace"].startswith("watchface-"))
        self.assertIn("--claim", self.calls[0])
        data = (self.project / "watchface/bin/TokenQuota.SET").read_bytes()
        self.assertIn(f"https://mantledb.sh/v2/{config['namespace']}/data/entry".encode(), data)
        self.assertNotIn(b"local-write-secret", data)
        self.assertNotIn("local-write-secret", self.output.getvalue())
        self.assertEqual(Path(self.calls[-1][1]).name, "schedule-collector.py")

    def test_rerun_reuses_namespace_and_token(self):
        setup_collector.setup("my-test-quota")
        original = self.config.read_bytes()
        self.calls.clear()
        setup_collector.setup()
        self.assertNotIn("--claim", self.calls[0])
        self.assertEqual(self.config.read_bytes(), original)

    def test_conflicting_namespace_is_rejected_before_any_changes(self):
        setup_collector.setup("my-test-quota")
        self.calls.clear()
        with self.assertRaisesRegex(ValueError, "different namespace"):
            setup_collector.setup("another-quota")
        self.assertEqual(self.calls, [])

    def test_failed_publication_can_resume_without_claiming_again(self):
        self.fail_at = "collect-quota.py"
        with self.assertRaises(subprocess.CalledProcessError):
            setup_collector.setup("my-test-quota")
        self.assertEqual(len(self.calls), 1)
        self.assertFalse((self.project / "watchface/bin/TokenQuota.SET").exists())
        self.fail_at = None
        self.calls.clear()
        setup_collector.setup()
        self.assertNotIn("--claim", self.calls[0])

    def test_generator_failure_prevents_scheduling(self):
        self.fail_at = "generate-settings.py"
        with self.assertRaises(subprocess.CalledProcessError):
            setup_collector.setup()
        self.assertFalse(any(Path(command[1]).name == "schedule-collector.py" for command in self.calls))

    def test_missing_tools_and_unsupported_platform_do_not_claim(self):
        with patch.object(setup_collector.sys, "platform", "linux"), self.assertRaises(RuntimeError):
            setup_collector.setup()
        with patch.object(setup_collector.shutil, "which", return_value=None), self.assertRaises(RuntimeError):
            setup_collector.setup()
        self.assertEqual(self.calls, [])
        self.assertFalse(self.config.exists())


if __name__ == "__main__":
    unittest.main()
