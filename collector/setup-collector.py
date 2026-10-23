#!/usr/bin/env python3
"""Publish the first quota snapshot, generate watch settings, and schedule updates on macOS."""

import argparse
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys
import uuid

PROJECT = Path(__file__).resolve().parents[1]


def setup(namespace=None):
    if sys.platform != "darwin":
        raise RuntimeError("Automatic collector setup requires macOS (the schedule uses launchd)")
    if not shutil.which("codex"):
        raise RuntimeError("Codex CLI not found on PATH. Install it and sign in before running setup.")
    if not shutil.which("launchctl"):
        raise RuntimeError("launchctl not found on PATH")
    if namespace is not None and not re.fullmatch(r"[a-z0-9][a-z0-9-]{2,63}", namespace):
        raise ValueError("Namespace must be 3–64 lowercase letters, digits or hyphens")

    config_path = PROJECT / ".local/collector.json"
    config = json.loads(config_path.read_text()) if config_path.exists() else None
    if config is not None and namespace is not None and namespace != config["namespace"]:
        raise ValueError("Collector already uses a different namespace. Rerun without --namespace to reuse it.")

    collect = [sys.executable, str(PROJECT / "collector/collect-quota.py")]
    if config is None:
        namespace = namespace or f"watchface-{uuid.uuid4().hex[:16]}"
        collect.extend(["--claim", namespace])
        print(f"Claiming {namespace} and publishing the first snapshot...", flush=True)
    else:
        print("Reusing the saved namespace and publishing a fresh snapshot...", flush=True)
    subprocess.run(collect, check=True)

    # Read the saved configuration, including after a new claim. Only the public
    # URL is passed to the settings generator; the write key stays in this file.
    config = json.loads(config_path.read_text())
    url = f"https://mantledb.sh/v2/{config['namespace']}/{config['path']}"
    print("Generating watch settings...", flush=True)
    subprocess.run([
        sys.executable, str(PROJECT / "watchface/scripts/generate-settings.py"), "--url", url,
    ], check=True)
    print("Installing the five-minute collector schedule...", flush=True)
    subprocess.run([
        sys.executable, str(PROJECT / "collector/schedule-collector.py"), "install",
    ], check=True)
    print("Setup complete. Keep this project in place so scheduled collection can find it.")
    print("Connect the watch as a USB drive, then run watchface/scripts/deploy.sh WATCH_ROOT.")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--namespace", help="Choose a new namespace (default: generate one, or reuse saved configuration)")
    args = parser.parse_args()
    try:
        setup(args.namespace)
    except (OSError, ValueError, KeyError, RuntimeError, subprocess.CalledProcessError) as error:
        parser.exit(1, f"Setup failed: {error}\nFix the problem and rerun setup; any saved namespace will be reused.\n")


if __name__ == "__main__":
    main()
