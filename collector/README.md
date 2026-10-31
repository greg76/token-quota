# Collector development

Develop and test the Python collector that publishes Codex quota for the watchface. For installation, scheduling commands, logs, and troubleshooting, refer to the [user guide](../README.md). Commands below run from the repository root.

## Codex integration

The Python collector reads the signed-in account through `codex app-server` and its `account/rateLimits/read` method. It initializes the connection and reads limits without starting an inference turn. Python 3 and the signed-in Codex CLI are required. No Python packages are needed.

The collector produces the [shared payload](../quota-payload.md) and publishes it to MantleDB. Other provider integrations must preserve that contract.

## Setup and publication

`setup-collector.py` performs these steps in order:

1. On first setup, claim an automatically generated namespace, or the name supplied with `--namespace`. This saves the secret write token, publishes `data/entry`, enables public reads for that entry, and verifies an unauthenticated read.
2. Generate `watchface/bin/TokenQuota.SET` using the saved namespace’s public URL. The write token is not included.
3. Install the per-user macOS job to publish updates every five minutes.

Setup uses Python’s standard library and invokes the collector, settings generator, and scheduler in order. If a step fails, subsequent steps do not run.

To choose a namespace for a development installation, run `./collector/setup-collector.py --namespace your-unique-namespace`. The collector requires namespace names to contain 3–64 lowercase letters, digits, or hyphens and start with a letter or digit. Refer to the [MantleDB API documentation](https://mantledb.sh/#api) for namespace claiming and access rules. Setup refuses to switch an existing configuration to a different namespace. Rerunning setup reuses the saved namespace and retries publication, settings generation, and schedule installation.

A failed Codex read leaves the last publication unchanged. A failed publication or verification exits with an error. The collector selects the `codex` bucket and identifies 5H and 7D windows by their supplied duration. Other buckets and durations are not substituted. A missing window or reset timestamp produces `null` for that window; if both windows are unavailable, collection fails without publishing.

## Scheduler implementation

`schedule-collector.py` installs a per-user launchd job. The generated job is also saved under `.local/`. Overlapping collector invocations are skipped. A successful publication updates `.local/collector-status.json`; publication or verification failures preserve the previous status.

## Run tests

These checks run offline without contacting MantleDB or installing jobs:

```sh
./collector/test-collector.py
./collector/test-setup.py
```

### Test publication against MantleDB

To test the collector in isolation on first setup, run:

```sh
./collector/collect-quota.py --claim YOUR-UNIQUE-NAMESPACE
```

This claims a real namespace, saves its write token, publishes quota, and prints the public URL. It does not generate watch settings or install a schedule. Use this command only when testing those collector operations independently; use `setup-collector.py --namespace` for a complete installation with a custom namespace.

Without saved configuration, running the collector without `--claim` fails with `First run requires --claim NAMESPACE`. After the initial claim, run `./collector/collect-quota.py` to publish using the saved configuration.

## Test coverage

Nine Python tests cover the collector contract, anonymous publication verification, and preservation of the last successful status on verification or status replacement failure. Six setup tests cover initial installation, retries, namespace reuse, and failure handling without contacting MantleDB or installing jobs.
