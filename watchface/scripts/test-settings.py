#!/usr/bin/env python3
"""Check standalone settings generation without Codex or the Garmin SDK."""

import importlib.util
from pathlib import Path
import struct
import subprocess
import sys
import tempfile
import unittest

SCRIPT = Path(__file__).with_name("generate-settings.py")
spec = importlib.util.spec_from_file_location("settings", SCRIPT)
settings = importlib.util.module_from_spec(spec)
spec.loader.exec_module(settings)

# Saved by the Garmin SDK 9.3.0 simulator's properties editor, then compared
# byte for byte with our independently generated file.
SIMULATOR_SETTINGS = bytes.fromhex(
    "abcdabcd0000004b000b44617461536f7572636500000d4d6f636b5363656e6172696f00"
    "000951756f746155726c00002268747470733a2f2f6578616d706c652e636f6d2f71756f"
    "74613f70726f62653d3100da7ada7a000000230b0000000303000000000100000000"
    "030000000d0100000000030000001c0300000027"
)


class SettingsTests(unittest.TestCase):
    def test_matches_garmin_simulator_file(self):
        self.assertEqual(settings.settings_bytes("https://example.com/quota?probe=1"), SIMULATOR_SETTINGS)

    def test_utf8_lengths_and_string_reference(self):
        url = "https://example.com/" + "é" * 150
        data = settings.settings_bytes(url)
        string_length = struct.unpack_from(">I", data, 4)[0]
        strings = data[8:8 + string_length]
        # The last dictionary value points to the URL in the string section.
        offset = struct.unpack_from(">I", data, len(data) - 4)[0]
        length = struct.unpack_from(">H", strings, offset)[0]
        self.assertEqual(length, len(url.encode("utf-8")) + 1)
        self.assertEqual(strings[offset + 2:offset + 2 + length], url.encode("utf-8") + b"\0")

    def test_rejects_invalid_or_oversized_urls(self):
        for url in ["", "http://example.com/quota", "https:///quota", "https://user:secret@example.com/quota",
                    "https://example.com/quota#fragment", "https://example.com/a b", "https://example.com/\0",
                    "https://example.com/" + "é" * 33000]:
            with self.subTest(url=url[:80]), self.assertRaises(ValueError):
                settings.settings_bytes(url)

    def test_cli_creates_file_and_preserves_it_on_invalid_input(self):
        with tempfile.TemporaryDirectory() as folder:
            output = Path(folder) / "nested/TokenQuota.SET"
            result = subprocess.run([sys.executable, str(SCRIPT), "--url", "https://example.com/quota?probe=1",
                                     "--output", str(output)], capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(output.read_bytes(), SIMULATOR_SETTINGS)
            result = subprocess.run([sys.executable, str(SCRIPT), "--url", "invalid", "--output", str(output)],
                                    capture_output=True, text=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertEqual(output.read_bytes(), SIMULATOR_SETTINGS)


if __name__ == "__main__":
    unittest.main()
