# Token Quota for Garmin Instinct 2X Solar

Display remaining five-hour and seven-day quota and time until reset on the Instinct 2X Solar. The included collector reads Codex quota and publishes it through MantleDB. Mock scenarios let you review the layout without live data. The clock uses local device time in 24-hour format. The battery icon uses the device battery level, with Garmin's estimated remaining days beside it. An unavailable estimate displays `--d`.

For installation with the included prebuilt signed [TokenQuota.prg](bin/TokenQuota.prg), follow [Install without the Garmin SDK](../README.md#install-without-the-garmin-sdk-macos). Commands below run from `watchface/`. The collector is documented in [../collector/README.md](../collector/README.md); the shared JSON format is in [../quota-payload.md](../quota-payload.md).

## Build and run

Requires the Connect IQ SDK with the `instinct2x` device installed, Java, and OpenSSL. The scripts find the active SDK through Garmin's `current-sdk.cfg` on macOS. Set `CIQ_SDK_HOME` to use another SDK location.

```sh
./scripts/build.sh             # bin/TokenQuota.prg
./scripts/run.sh               # Build and load the Instinct 2X simulator
./scripts/run.sh --test        # Run thirteen tests in the simulator
./scripts/build.sh -r          # Optional release build for sideloading
```

Zed's task picker includes **Garmin: Build Instinct 2X**, **Garmin: Run Instinct 2X simulator**, and **Garmin: Test Instinct 2X**. The run command stays attached to the simulator until the watch face stops.

The first build generates a local signing key at `../.local/developer_key.der`. Keep it if you want later builds to retain the same signing identity. `.local/` and build outputs other than the bundled `bin/TokenQuota.prg` are ignored by Git. Set `CIQ_DEVELOPER_KEY` to use an existing DER signing key.

### Simulator tests

`./scripts/run.sh --test` builds `bin/TokenQuotaTests.prg` with the Connect IQ compiler's `-t` option, then runs it with the simulator's test runner. This compiles the watchface code together with the tests in [source/WatchFaceTests.mc](source/WatchFaceTests.mc). The test functions and helpers are marked `(:test)` and excluded from normal builds.

The thirteen tests check:

- Gauge drawing at empty and full quota, and marker contrast at both ends and where markers overlap the fill.
- Rendering of every mock scenario with Garmin's drawing API, plus clock font width and height limits.
- Countdown rounding and progression between quota polls.
- Full session quota from a stored payload, missing data, invalid clocks, reset windows, and the 15-minute stale-data threshold.
- Payload validation, cache replacement rules for older or future observations, and default settings after upgrades.

The command writes results to `bin/test-results.log` and exits successfully only when the runner reports passing tests with no failures or errors. These checks are optional for development and are not required for building or sideloading the watchface. Run without `--test` to inspect the normal watchface; the automated checks do not assess visual readability or verify live network access on a physical watch.

## Configure your quota URL

New builds have no bundled quota URL. Live mode shows `SETUP`, leaves the gauges unknown (`...`), and does not schedule requests until **Public quota URL** (`QuotaUrl`) is configured. Mock mode works without a URL. Existing installations retain their saved URL; upgrading does not erase it. Changing application settings clears the cached quota snapshot before polling resumes.

For the included Codex collector, run `../collector/setup-collector.py`. It claims a namespace on first setup, generates `bin/TokenQuota.SET`, and starts the five-minute schedule. Later runs reuse the saved configuration. No manual settings generation is needed for this flow.

For another collector, generate settings with its public URL. A MantleDB URL has this form:

```text
https://mantledb.sh/v2/YOUR-NAMESPACE/data/entry
```

The watch reads this URL from application properties at runtime. Changing it does not require recompiling. Only the public URL belongs on the watch; keep the namespace write token on your computer.

### Sideloaded settings file

Sideloaded apps do not expose the normal phone-based Connect IQ settings interface. You can generate Garmin’s binary `.SET` file directly with Python 3, without Codex, the Garmin SDK, or recompiling the app:

```sh
./scripts/generate-settings.py --url https://mantledb.sh/v2/YOUR-NAMESPACE/data/entry
```

This writes `bin/TokenQuota.SET` with live mode selected and your public URL. Use `--output /path/to/TokenQuota.SET` to choose another location. Copy the `.prg` to `GARMIN/APPS/` and the `.SET` to `GARMIN/APPS/SETTINGS/` on the watch. Their basenames and case must match.

The generator matches the SDK 9.3.0 simulator’s settings encoding byte for byte, and its generated file was loaded successfully by the Instinct 2X simulator with an existing compiled watchface. The deployed program and companion settings have also been confirmed to work on a physical Instinct 2X. The encoding is based on observed simulator output rather than a documented Garmin compatibility guarantee. Run `./scripts/test-settings.py` for the standalone checks.

#### Optional: export simulator settings

`export-settings.py` is not needed when using `generate-settings.py`. Use it manually only if you want to transfer settings you edited in the simulator:

1. Run `./scripts/run.sh` without `--test`.
2. In **File → Edit Persistent Storage → Edit Application.Properties data**, set `DataSource` to `0` and `QuotaUrl` to your full public URL, then save.
3. Stop the watchface with **File → Kill App** so its settings are written.
4. Run `./scripts/export-settings.py`. This copies the simulator settings to `bin/TokenQuota.SET`; it does not rebuild the app.
5. Copy `bin/TokenQuota.prg` to `GARMIN/APPS/` and `bin/TokenQuota.SET` to `GARMIN/APPS/SETTINGS/` on the watch, then disconnect and select the face.

The settings filename must match the `.prg` basename, including case. If you rename one, rename the other. The export helper defaults to the macOS simulator location; pass `--source /path/to/TOKENQUOTA.SET` for another location. This is a Garmin settings file, not a JSON file beside the `.prg`.

## Mock scenarios

Select **Quota data source → Mock scenarios** (`DataSource = 1`) to use these scenarios. The default is **Live quota** (`DataSource = 0`).

All quota values are in `source/MockQuotaProvider.mc`, expressed as fractions from `0.0` to `1.0`. `QuotaSnapshot` keeps the 5H and 7D windows independent. The renderer has no networking or authentication code.

Select a scenario in the simulator through **File → Edit Persistent Storage → Edit Application.Properties data**, change the numeric `MockScenario` property, and save. The watch face requests a redraw when application settings change. These scenarios are also defined in the Connect IQ app settings resources.

| `MockScenario` | Scenario | 5H quota / period remaining | 7D quota / period remaining |
|---|---|---|---|
| 0 | Example (default) | 35% / 3h | 65% / 4d12h30m |
| 1 | Empty quota | 0% / 60% | 0% / 45% |
| 2 | Full quota | 100% / 60% | 100% / 45% |
| 3 | On pace | 50% / 50% | 50% / 50% |
| 4 | Ahead of pace | 80% / 40% | 80% / 40% |
| 5 | Behind pace | 25% / 70% | 25% / 70% |
| 6 | Period start | 100% / 100% | 100% / 100% |
| 7 | Period end | 0% / 0% | 0% / 0% |
| 8 | Countdown example | 35% / 58m | 65% / 4d12h30m |
| 9 | Under one minute | 10% / 30s | 10% / 30s |

The reset countdown replaces each static window label: right-aligned above the 7D bar with a 5px gap above its marker, and inside the 5H gauge. It selects days at 24h or more, hours at 1h or more, and minutes below 1h, then rounds to the nearest whole unit, with halves rounding up. Examples: 4h59m becomes `-5h`, 4d12h30m becomes `-5d`, and 58m becomes `-58m`. Rounding preserves the selected unit: 59m40s shows `-60m`, and 23h40m shows `-24h`. Positive durations below one minute show `-<1m`; a period with no time remaining shows `0m`. Positions identify the two windows. Mock durations are fixed per scenario rather than ticking down.

Both gauges fill from left to right. White fill represents quota remaining; the thin white marker with a black border represents period remaining. A fill endpoint farther right than the marker means quota is ahead of linear consumption pace. The black border preserves marker visibility when it overlaps the fill.

## Layout and verification

The target is the Instinct 2X's 176 × 176, 1-bit display. The 5H gauge uses `WatchUi.getSubscreen()` for the physical 62 × 62 circular area at `(113, 0)`. The 7D bar and its right-aligned countdown end at x=95, leaving clearance from the physical overlay. The battery body is 22 × 15 pixels, matching the visible height of its text. The clock uses the exact Garmin sleep-clock bitmap glyphs, with a 58px visible height and a 143px advance for four-digit times. It contains only `0–9` and `:`, is loaded once, and is drawn with one native `drawText()` call centered at `(88, 112)`. The clock clears the prompt and battery row. Other text uses device fonts. Normal watch-face updates show the current minute without a per-second timer. Single-digit hours retain a leading zero.

Verified with Connect IQ SDK 9.3.0 and the Instinct 2X Solar simulator (API 3.4.3):

- Normal build passes without warnings; default layout visually inspected for clipping and readability.
- Thirteen simulator tests pass, covering gauge drawing, native rendering, countdown rounding and progression, unavailable and reset windows, stale data, payload validation, clock errors, and cache ordering. Collector checks are documented in [../collector/README.md](../collector/README.md).

Tests exercise drawing calls and device rendering, but do not automatically assess visual readability. The sideloaded build has been confirmed to fetch and display live data on a physical Instinct 2X. Phone background operation has not yet been verified there.

## Watch refresh and unavailable data

The watch fetches the public URL in a five-minute background event and persists valid responses. The collector and watch poll independently, so quota observations can approach ten minutes old even with both working normally. Garmin can delay background execution further. A failed HTTP read or invalid payload preserves the last valid snapshot. Older observations cannot replace newer ones.

- `...`: waiting for the first valid reading, a missing window, an unusable clock, or a reset awaiting a new reading. The gauge outline remains visible without a fill or time marker.
- `!` at the top left: the cached observation is at least 15 minutes old. Quota fill remains at its last known value; the countdown and time marker continue advancing.

The watch never assumes quota has returned to 100% after a reset; it shows `...` until a new reading arrives.

Fetch diagnostics are retained in Application.Storage under `quotaFetchStatusV1`; they are not drawn on the watch face. Waiting and unavailable countdowns use `...` without animation. Diagnostic values:

| Label | Meaning |
|---|---|
| No stored status | No fetch has started yet. |
| `FETCH` | The background request started and has not returned a result. |
| `E403` | HTTP access denied. MantleDB's Cloudflare protection rejects some client signatures; the app explicitly sends `User-Agent: TokenQuota/1.0`, which was verified to return the public JSON. |
| `E-104` | Garmin reports that no Bluetooth connection is available for the request. |
| Other `E…` | HTTP status or Garmin communications error code. |
| `DATA` | The response did not match the expected quota payload. |
| `TIME` | The observation time cannot be accepted, or the cached data failed the clock check. |

A missing `DataSource` setting selects live mode. A missing or empty `QuotaUrl` requires setup; there is no fallback public URL. The background task schedules the following five-minute interval before starting its request, so transient request failures do not stop polling.

In the simulator, use **Simulation → Background Events → Temporal Event**, target **Token Quota**, and confirm to trigger a fetch. Live fetching and readable rendering have been verified there. Garmin reference: [background scheduling](https://developer.garmin.com/connect-iq/api-docs/Toybox/Background.html#registerForTemporalEvent-instance_function). Service references: [Codex rate limits](https://learn.chatgpt.com/docs/app-server#6-rate-limits-chatgpt), [MantleDB API](https://mantledb.sh/#api).

## Sideload onto the watch

1. Use the included prebuilt signed `bin/TokenQuota.prg`. Developers can rebuild it with `./scripts/build.sh -r`.
2. Run `../collector/setup-collector.py` for the included Codex collector. It generates `bin/TokenQuota.SET`; other collectors can use the [configuration instructions](#configure-your-quota-url).
3. Connect the Instinct 2X over USB and wait for its storage to mount as a filesystem path. If needed, select **System → USB Mode → Mass Storage** on the watch, as described in the [USB connection instructions](../README.md#2-connect-the-watch).
4. Run `./scripts/deploy.sh /Volumes/GARMIN`, replacing `/Volumes/GARMIN` with the watch’s mount path. The script copies the program to `GARMIN/APPS/TokenQuota.prg` and settings to `GARMIN/APPS/SETTINGS/TokenQuota.SET`, replacing existing files. It checks both source files and requires an existing `GARMIN/APPS` folder before copying. No Garmin SDK or Codex installation is needed for deployment.
5. The script verifies both copies and ejects the watch using macOS `diskutil`. After successful ejection, disconnect and select **Token Quota** in the watch-face picker. On other platforms, eject manually when prompted. If copying or verification fails, the script stops before ejection.

If your USB transfer tool only provides a file browser rather than a mounted filesystem path, copy the two files manually to those destinations.

Live reads require the watch to be connected by Bluetooth to a phone with Internet access and Garmin Connect allowed to run in the background. Garmin Connect does not need to remain on screen; the Connect IQ Store app is not required for these reads. On iOS, enable Background App Refresh and Bluetooth for Connect, allow cellular data if needed, and avoid force-quitting Connect. Low Power Mode can delay background work. On Android, allow Connect to run in the background and remove battery restrictions if updates stall. This quota feature does not need the location permission used by weather.

Once a quota URL is configured, the first fetch is scheduled immediately, subject to Garmin's minimum five-minute interval since the previous background event and device scheduling. Foreground watch-face code cannot make HTTP requests. Once a reading has been cached, returning to the face displays it immediately while background polling continues.

Garmin API reference: [sub-display geometry](https://developer.garmin.com/connect-iq/api-docs/Toybox/WatchUi.html#getSubscreen-instance_function), [native drawing primitives](https://developer.garmin.com/connect-iq/api-docs/Toybox/Graphics/Dc.html).

## Clock font asset

The bitmap font (`resources/fonts/clock.fnt` and `clock.png`) is checked in, so normal builds need no font tooling. Its source is Garmin's `FNT_006B458400_0000_GARMIN_65.cft`, distributed with Instinct 3 Solar and Instinct E device resources. The source glyphs and their spacing reproduce the Instinct 2X sleep-screen. Digits have a 32px advance; the colon has a 15px advance, two 9 × 8px marks, and 23 blank rows between the marks. The exporter removes common blank rows above and below the glyphs while preserving their pixels, horizontal offsets, and advances.

To regenerate it, run `./scripts/generate-clock-font.py` with Pillow installed. By default, the script reads the source from `~/Library/Application Support/Garmin/ConnectIQ/Fonts/`. On another installation, pass `--source /path/to/FNT_006B458400_0000_GARMIN_65.cft`. The script verifies the source file's SHA-256 before exporting. It does not resize or smooth the glyphs. The CFT decoder is adapted from [Mark Williams's font analyzer](https://github.com/markw65/monkeyc-optimizer/blob/main/src/cftinfo.ts), with its MIT license in `scripts/cft-parser-LICENSE.txt`.
