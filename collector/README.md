# Codex quota collector

Publish your remaining Codex quota so the watchface can display it. Run the commands below from the repository root. Watch setup is documented in [../watchface/README.md](../watchface/README.md); the shared JSON format is in [../quota-payload.md](../quota-payload.md). Local configuration and logs live in the repository root’s `.local/` directory.

The Python collector reads the signed-in account through `codex app-server` and its `account/rateLimits/read` method. It initializes the connection and reads limits without starting an inference turn. Python 3 and the signed-in Codex CLI are required. No Python packages are needed.

This collector supports Codex only; use it as an example for other providers that can produce the [shared payload](../quota-payload.md). It publishes to [MantleDB](https://mantledb.sh/), a hosted JSON store. On first setup with `--claim NAMESPACE`, the script claims a namespace and saves its secret write token in `.local/collector.json` with owner-only permissions. Back up that file; it is ignored by Git and needed for future writes. Anyone with the public URL can read the remaining quota, reset times, and observation time. MantleDB receives the write token when the collector publishes; the watch receives only the public URL. No prompts, conversations, or Codex authentication credentials are copied to MantleDB or the watch.

## Set up collection and watch settings

On macOS, with Python 3 and the signed-in Codex CLI available, run:

```sh
./collector/setup-collector.py
```

The setup script performs these steps in order:

1. On first setup, automatically choose a unique namespace and run `collect-quota.py --claim NAMESPACE`. This saves the secret write token, publishes `data/entry`, enables public reads for that entry, and verifies an unauthenticated read.
2. Generate `watchface/bin/TokenQuota.SET` using the saved namespace’s public URL. The write token is not included.
3. Install the per-user macOS job to publish updates every five minutes.

Setup uses Python’s standard library and the existing collector, settings generator, and scheduler. It does not require the Garmin SDK, Java, a signing key, or the simulator. Use the included prebuilt signed [TokenQuota.prg](../watchface/bin/TokenQuota.prg) and follow the [USB deployment instructions](../README.md#2-connect-the-watch) to install both files.

Rerunning setup reuses `.local/collector.json`, publishes a fresh reading, regenerates the settings, and replaces the schedule. If a step fails, subsequent steps do not run. Fix the error and rerun; a namespace saved by a previous attempt is reused. If you want to choose the initial namespace yourself:

```sh
./collector/setup-collector.py --namespace your-unique-namespace
```

Namespaces must contain 3–64 lowercase letters, digits, or hyphens and start with a letter or digit. Setup refuses to switch an existing configuration to a different namespace. Keep this project folder in place for scheduled collection, and rerun setup if you move it.

## Manual collection

These commands are useful for troubleshooting or running collection without installing the schedule:

```sh
./collector/collect-quota.py --claim YOUR-UNIQUE-NAMESPACE  # First claim and publication only
./collector/collect-quota.py --dry-run                     # Read without publishing
./collector/collect-quota.py                               # Publish with saved configuration
./collector/test-collector.py                              # Offline collector tests
./collector/test-setup.py                                  # Offline setup tests
```

The low-level collector does not claim a namespace automatically: without `.local/collector.json`, a normal run exits with `First run requires --claim NAMESPACE`. Use the setup script for the complete installation flow. A successful manual claim prints the public quota URL but does not generate watch settings or install a schedule.

A failed Codex read leaves the last publication unchanged. A failed publication or verification exits with an error. The collector selects the `codex` bucket and identifies 5H and 7D windows by their supplied duration. Other buckets and durations are not substituted. A missing window or reset timestamp produces `null` for that window; if both windows are unavailable, collection fails without publishing.

## Five-minute schedule

Setup installs the per-user macOS job `local.watchface-tokens.collector`, which runs every 300 seconds. It starts at login and runs while this Mac is awake. Sleep, logout, network loss, or expired Codex authentication can delay updates. Overlapping collector invocations are skipped.

```sh
./collector/schedule-collector.py install  # Install or replace the launchd job
./collector/schedule-collector.py remove   # Stop and remove it
launchctl print gui/$(id -u)/local.watchface-tokens.collector
```

The installed file is `~/Library/LaunchAgents/local.watchface-tokens.collector.plist`. The exact generated job is also saved under `.local/`. Logs are `.local/collector.log` and `.local/collector-error.log`; reinstall after moving this project or changing Python/Codex locations. The logs are not automatically rotated.

## Test coverage

Eight Python tests cover the collector contract and anonymous publication verification. Six setup tests cover initial installation, retries, namespace reuse, and failure handling without contacting MantleDB or installing jobs.
