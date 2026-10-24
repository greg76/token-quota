#!/usr/bin/env python3
"""Install or remove the per-user macOS launchd collector job."""

import argparse
import os
import plistlib
import shutil
import subprocess
import sys
from pathlib import Path

PROJECT = Path(__file__).resolve().parents[1]
LABEL = "local.watchface-tokens.collector"
PLIST = Path.home() / "Library/LaunchAgents" / f"{LABEL}.plist"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=["install", "remove"])
    args = parser.parse_args()
    target = f"gui/{os.getuid()}"
    if args.action == "remove":
        subprocess.run(["launchctl", "bootout", f"{target}/{LABEL}"], check=False)
        PLIST.unlink(missing_ok=True)
        return
    if not (PROJECT / ".local/collector.json").is_file():
        parser.error("Configure and publish with collect-quota.py --claim first")
    codex = shutil.which("codex")
    if not codex:
        parser.error("Codex CLI is not on PATH")
    job = {
        "Label": LABEL,
        "ProgramArguments": [
            sys.executable,
            str(PROJECT / "collector/collect-quota.py"),
            "--codex",
            codex,
        ],
        "WorkingDirectory": str(PROJECT),
        "EnvironmentVariables": {
            "PATH": f"{Path(codex).parent}:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
        },
        "RunAtLoad": True,
        "StartInterval": 300,
        "ProcessType": "Background",
        "StandardOutPath": "/dev/null",
        "StandardErrorPath": str(PROJECT / ".local/collector-error.log"),
    }
    # Prepare the exact job in the project before installing it.
    prepared = PROJECT / ".local" / PLIST.name
    prepared.write_bytes(plistlib.dumps(job))
    PLIST.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(["launchctl", "bootout", f"{target}/{LABEL}"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    shutil.copyfile(prepared, PLIST)
    subprocess.run(["launchctl", "bootstrap", target, str(PLIST)], check=True)
    print(f"Installed {LABEL}: every 300 seconds while this Mac is awake and you are logged in")


if __name__ == "__main__":
    main()
