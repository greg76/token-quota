#!/usr/bin/env python3
"""Read Codex quotas and publish a small, public watch snapshot. No dependencies."""

import argparse
import datetime
import fcntl
import json
import math
import os
import selectors
import shutil
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.request
from pathlib import Path

PROJECT = Path(__file__).resolve().parents[1]
CONFIG = PROJECT / ".local/collector.json"
STATUS = PROJECT / ".local/collector-status.json"
BASE_URL = "https://mantledb.sh/v2"
RPC_TIMEOUT_SECONDS = 45


def request_json(url, method="GET", data=None, key=None):
    headers = {"Accept": "application/json", "User-Agent": "TokenQuota/1.0"}
    if data is not None:
        headers["Content-Type"] = "application/json"
    if key:
        headers["X-Mantle-Key"] = key
    request = urllib.request.Request(
        url, data=None if data is None else json.dumps(data).encode(),
        headers=headers, method=method,
    )
    with urllib.request.urlopen(request, timeout=30) as response:
        return json.load(response)


def read_codex(codex):
    # Only initialize and read limits: never start a thread or an inference turn.
    with subprocess.Popen(
        [codex, "app-server", "--listen", "stdio://"],
        stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
    ) as process:
        selector = selectors.DefaultSelector()
        selector.register(process.stdout, selectors.EVENT_READ)
        pending = b""

        def send(message):
            process.stdin.write(json.dumps(message).encode() + b"\n")
            process.stdin.flush()

        def receive(request_id):
            nonlocal pending
            deadline = time.monotonic() + RPC_TIMEOUT_SECONDS
            while True:
                while b"\n" in pending:
                    line, pending = pending.split(b"\n", 1)
                    message = json.loads(line)
                    if message.get("id") != request_id:
                        continue
                    if "error" in message:
                        error = message["error"]
                        raise RuntimeError(f"Codex RPC {error.get('code')}: {error.get('message')}")
                    return message["result"]
                remaining = deadline - time.monotonic()
                if remaining <= 0 or not selector.select(remaining):
                    raise TimeoutError("Codex rate-limit read timed out")
                chunk = os.read(process.stdout.fileno(), 65536)
                if not chunk:
                    raise RuntimeError("Codex app-server exited before replying")
                pending += chunk

        try:
            send({"id": 1, "method": "initialize", "params": {
                "clientInfo": {"name": "token_quota_collector", "title": "Token Quota", "version": "1.0"},
                "capabilities": None,
            }})
            receive(1)
            send({"method": "initialized"})
            send({"id": 2, "method": "account/rateLimits/read"})
            result = receive(2)
            return result, int(time.time())
        finally:
            selector.close()
            process.terminate()
            try:
                process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait()


def snapshot_from_limits(result, observed_at, bucket_id="codex"):
    buckets = result.get("rateLimitsByLimitId")
    if buckets is not None:
        bucket = buckets.get(bucket_id)
    else:
        bucket = result.get("rateLimits")
        if bucket and bucket.get("limitId") not in (None, bucket_id):
            bucket = None
    if not isinstance(bucket, dict):
        raise ValueError(f"Codex quota bucket {bucket_id!r} unavailable")
    snapshot = {"schemaVersion": 1, "observedAt": observed_at, "weekly": None, "session": None}
    for window in (bucket.get("primary"), bucket.get("secondary")):
        if not isinstance(window, dict):
            continue
        minutes = window.get("windowDurationMins")
        name = {300: "session", 10080: "weekly"}.get(minutes)
        if name is None:
            continue
        used, reset = window.get("usedPercent"), window.get("resetsAt")
        if reset is None or used is None:
            continue
        if isinstance(used, bool) or not isinstance(used, (float, int)) or not math.isfinite(used) or used < 0:
            raise ValueError("Invalid Codex usedPercent")
        if type(reset) is not int or reset <= 0 or reset > observed_at + minutes * 60 + 300:
            raise ValueError("Invalid Codex reset timestamp")
        if snapshot[name] is not None:
            raise ValueError(f"Duplicate {name} quota window")
        snapshot[name] = {
            "quotaRemaining": round(max(0.0, min(1.0, 1 - used / 100)), 6),
            "durationSeconds": minutes * 60,
            "resetsAt": reset,
        }
    if snapshot["weekly"] is None and snapshot["session"] is None:
        raise ValueError("Neither a 5H nor a 7D quota window was available; keeping last publication")
    return snapshot


def save_config(config):
    CONFIG.parent.mkdir(parents=True, exist_ok=True)
    # The write key is stored only in this ignored, owner-readable file.
    fd = os.open(CONFIG, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    os.fchmod(fd, 0o600)
    with os.fdopen(fd, "w") as stream:
        json.dump(config, stream, indent=2)
        stream.write("\n")
        stream.flush()
        os.fsync(stream.fileno())


def publish(config, snapshot):
    namespace, path, key = config["namespace"], config["path"], config["key"]
    url = f"{BASE_URL}/{namespace}/{path}"
    request_json(url, "POST", snapshot, key)
    request_json(f"{BASE_URL}/visibility/{namespace}/{path}", "PUT", {"public_read": True}, key)
    # Deliberately omit the key: validate exactly what the watch can read.
    if request_json(url) != snapshot:
        raise RuntimeError("Anonymous read did not match the published snapshot")
    status = {
        "last_success_at": datetime.datetime.now(datetime.timezone.utc).isoformat(),
        "url": url,
    }
    STATUS.parent.mkdir(parents=True, exist_ok=True)
    temporary = None
    try:
        with tempfile.NamedTemporaryFile(
            mode="w", encoding="utf-8", dir=STATUS.parent, delete=False
        ) as stream:
            temporary = Path(stream.name)
            json.dump(status, stream, indent=2)
            stream.write("\n")
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temporary, STATUS)
    finally:
        if temporary is not None:
            temporary.unlink(missing_ok=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dry-run", action="store_true", help="Read Codex and print payload without publishing")
    parser.add_argument("--claim", metavar="NAMESPACE", help="Claim a new namespace and publish the first snapshot")
    parser.add_argument("--codex", default=shutil.which("codex"), help="Absolute Codex CLI path")
    args = parser.parse_args()
    if args.dry_run and args.claim:
        parser.error("--dry-run and --claim cannot be combined")
    if not args.codex:
        parser.error("Codex CLI not found; pass --codex")
    CONFIG.parent.mkdir(parents=True, exist_ok=True)
    with (CONFIG.parent / "collector.lock").open("w") as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            return
        config = json.loads(CONFIG.read_text()) if CONFIG.exists() else None
        if args.claim and config:
            parser.error("Collector is already configured; refusing to claim another namespace")
        if not args.dry_run and not args.claim and not config:
            parser.error("First run requires --claim NAMESPACE")
        result, observed_at = read_codex(args.codex)
        snapshot = snapshot_from_limits(result, observed_at)
        if args.dry_run:
            print(json.dumps(snapshot, indent=2))
            return
        if args.claim:
            import re
            if not re.fullmatch(r"[a-z0-9][a-z0-9-]{2,63}", args.claim):
                parser.error("Namespace must be 3–64 lowercase letters, digits or hyphens")
            claim = request_json(f"{BASE_URL}/claim/{args.claim}")
            if not claim.get("key"):
                raise RuntimeError("Claim did not return a write key")
            config = {"namespace": args.claim, "path": "data/entry", "key": claim["key"]}
            save_config(config)
        publish(config, snapshot)
        if args.claim:
            print(f"Public quota URL: {BASE_URL}/{config['namespace']}/{config['path']}")
            print("Set the watchface's QuotaUrl property to this URL; do not copy the write key to the watch.")


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, RuntimeError, urllib.error.URLError) as error:
        print(f"Collector failed: {error}", file=sys.stderr)
        sys.exit(1)
