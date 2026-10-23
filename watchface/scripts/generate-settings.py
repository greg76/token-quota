#!/usr/bin/env python3
"""Create Token Quota's Garmin .SET file using only Python's standard library."""

import argparse
from pathlib import Path
import struct
from urllib.parse import urlsplit

STRING_SECTION_MAGIC = 0xABCDABCD
DATA_SECTION_MAGIC = 0xDA7ADA7A
TYPE_NUMBER = 1
TYPE_STRING = 3
TYPE_DICTIONARY = 11
WATCHFACE = Path(__file__).resolve().parent.parent


def settings_bytes(url):
    """Encode the app's three properties in Garmin's serialized object format."""
    parsed = urlsplit(url)
    if (parsed.scheme != "https" or not parsed.hostname or parsed.username is not None
            or parsed.password is not None or parsed.fragment
            or any(character.isspace() or ord(character) < 32 for character in url)):
        raise ValueError("Use a public HTTPS quota URL without credentials, spaces, or a fragment")

    strings = bytearray()

    def string_reference(value):
        encoded = value.encode("utf-8") + b"\0"
        if len(encoded) > 65535:
            raise ValueError("URL exceeds Garmin's string length limit")
        offset = len(strings)
        strings.extend(struct.pack(">H", len(encoded)))
        strings.extend(encoded)
        return struct.pack(">BI", TYPE_STRING, offset)

    # Live mode and the default mock scenario; only QuotaUrl is user supplied.
    values = [("DataSource", 0), ("MockScenario", 0), ("QuotaUrl", url)]
    data = bytearray(struct.pack(">BI", TYPE_DICTIONARY, len(values)))
    for key, value in values:
        data.extend(string_reference(key))
        if isinstance(value, str):
            data.extend(string_reference(value))
        else:
            data.extend(struct.pack(">Bi", TYPE_NUMBER, value))
    return (struct.pack(">II", STRING_SECTION_MAGIC, len(strings)) + strings
            + struct.pack(">II", DATA_SECTION_MAGIC, len(data)) + data)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--url", required=True, help="Public quota JSON URL, not the namespace write token")
    parser.add_argument("--output", type=Path, default=WATCHFACE / "bin/TokenQuota.SET")
    args = parser.parse_args()
    try:
        data = settings_bytes(args.url)
    except ValueError as error:
        parser.error(str(error))
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_bytes(data)
    print(f"Created {args.output}")
    print("Copy to GARMIN/APPS/SETTINGS/ on the watch; its basename and case must match the .prg file.")


if __name__ == "__main__":
    main()
