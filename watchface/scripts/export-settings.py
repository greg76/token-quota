#!/usr/bin/env python3
"""Export the simulator's Garmin settings file for sideloading. No dependencies."""

import argparse
import shutil
import tempfile
from pathlib import Path

WATCHFACE = Path(__file__).resolve().parent.parent


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--source",
        type=Path,
        default=Path(tempfile.gettempdir())
        / "com.garmin.connectiq/GARMIN/APPS/SETTINGS/TOKENQUOTA.SET",
        help="Simulator .SET file (default: macOS simulator location)",
    )
    parser.add_argument("--output", type=Path, default=WATCHFACE / "bin/TokenQuota.SET")
    args = parser.parse_args()
    if not args.source.is_file():
        parser.error(
            "Simulator settings not found. Run the normal watchface, save its application properties, then stop it. Use --source for another simulator location."
        )
    args.output.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(args.source, args.output)
    print(f"Exported {args.output}")
    print(
        "Copy to GARMIN/APPS/SETTINGS/ on the watch. Its basename must match the .prg file."
    )


if __name__ == "__main__":
    main()
