# Garmin Token Watchface — Codex Handover

Historical phase-1 specification. Live collection, publishing, scheduling, and watch reads were subsequently authorized and implemented. Refer to [README.md](README.md) for the current behavior and setup.

## Objective

Build a native Garmin Connect IQ watchface for the **Garmin Instinct 2X Solar**, using Monkey C and the official Garmin SDK.

The first milestone is a working watchface in the Garmin simulator, followed by testing on physical hardware.

**Scope for now: mocked quota data only.** Do not implement HTTP requests, authentication, a backend, or any live OpenAI integration yet.

## Development environment

- Editor: Zed (not VS Code)
- Toolchain: Garmin Connect IQ SDK, Monkey C CLI, Garmin simulator
- Provide simple build/run scripts or Zed tasks.
- Target the Instinct 2X Solar specifically.

## Visual specification

Use the attached agreed mockup as the visual reference, with the following requirements taking precedence.

The Instinct 2X has a **176 × 176 monochrome display with a separate circular sub-display**. Respect the actual device geometry and available drawing regions.

Strictly black and white: no grayscale, gradients or antialiasing. Prioritize readability, clean geometry and minimal visual noise.

### Main clock

- Large `HH:MM`, 24-hour format, using actual device time.
- Dominates the central/lower display area.
- Modern, highly legible font, ideally similar to Garmin's built-in sleep-mode watchface.
- Maximize clock size without clipping.

### Top-left: 7-day quota

- Horizontal progress bar, confined to the space left of the circular sub-display.
- `7D` label immediately to the right of the bar.
- Filled portion = quota remaining.
- Thin vertical marker = fraction of the 7-day period remaining.
- Comparing fill endpoint and marker indicates ahead/behind linear consumption pace.
- No percentage, duration, or additional labels.

### Top-right circular sub-display: 5-hour quota

- Semicircular analogue-style gauge.
- Filled arc = 5H quota remaining.
- Empty arc = consumed quota.
- Thin radial marker = fraction of the 5H period remaining.
- Centered `5H` label.
- No numeric percentage.
- Use solid white fill and an outlined/empty arc, not different gray shades.
- The 5H gauge always represents 5H data, never the minimum of 5H and 7D.

Both gauges must use consistent semantics and clearly show the relationship between remaining quota and remaining time.

### Bottom: watch battery

- Small battery icon and estimated remaining days, e.g. `20d`.
- Use actual device battery data where available.
- No redundant percentage or `LEFT` label.

## Mock data

Make the quota values configurable in one place.

Example:

| Window | Quota remaining | Period remaining |
|---|---:|---:|
| 5H | 35% | 60% |
| 7D | 65% | 45% |

Include test scenarios for 0%, 100%, on-pace, ahead-of-pace and behind-pace states, including overlapping marker and fill positions.

## Implementation priorities

1. Establish a minimal compiling and running Connect IQ watchface project.
2. Implement the agreed layout with device-correct geometry.
3. Render the real local clock and battery information.
4. Add configurable mocked quota values.
5. Validate readability, arc drawing, marker visibility and clipping in the Garmin simulator.
6. Make the resulting `.prg` sideloadable onto the Instinct 2X.

Use native drawing primitives where practical. Keep quota data provision separate from rendering so live data can be added later without changing the UI.

## Out of scope

- OpenAI/Codex API integration
- Networking and background refresh
- Backend hosting
- Authentication
- Connect IQ Store publishing
- Supporting additional Garmin models

## Acceptance criteria

The watchface compiles, runs in the Instinct 2X simulator, respects the actual monochrome display constraints, and closely matches the attached mockup.

The large clock remains the visual centerpiece. Both quota gauges communicate remaining quota versus remaining period time without extra numeric labels.

**Prioritize simulator-verified layout fidelity over the visual mockup wherever they conflict.**
