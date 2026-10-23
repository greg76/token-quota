# Quota payload contract

Shared by the [collector](collector/README.md) and the [watchface](watchface/README.md).

Illustrative snapshot:

```json
{
  "schemaVersion": 1,
  "observedAt": 1800000000,
  "weekly": {
    "quotaRemaining": 0.65,
    "durationSeconds": 604800,
    "resetsAt": 1800390600
  },
  "session": {
    "quotaRemaining": 0.35,
    "durationSeconds": 18000,
    "resetsAt": 1800010800
  }
}
```

`quotaRemaining` is a fraction between 0 and 1, computed as `1 - usedPercent / 100` and clamped to that range. `resetsAt` is copied from Codex. `observedAt` is the collector's time immediately after a successful quota read. Both timestamps are integer Unix seconds; no timezone offsets or milliseconds are used. Keep automatic time synchronization enabled on the collector machine.

The watch uses Garmin's real-time clock for quota calculations, independently of the displayed local clock. It calculates `max(0, resetsAt - now)` and divides by `durationSeconds` for the time marker. These values update on normal minute refreshes between polls. Timezone and daylight saving changes do not change the countdown. Invalid real-time clock readings or observations more than five minutes in the future produce unknown values.

