using Toybox.Lang;
using Toybox.Time;

// Shared by the background reader and foreground provider. Reject malformed
// responses before replacing the cached snapshot. All timestamps are Unix seconds.
(:background)
module QuotaPayload {
    const STORAGE_KEY = "quotaSnapshotV1";
    const STATUS_KEY = "quotaFetchStatusV1";
    const POLL_SECONDS = 300;
    const STALE_SECONDS = 15 * 60;
    const CLOCK_TOLERANCE_SECONDS = 300;

    function nowSeconds() {
        try {
            return Time.getCurrentTime({:currentTimeType => Time.CURRENT_TIME_RTC}).value();
        } catch (error) {
            return null;
        }
    }

    function canReplace(previous, data, now) {
        if (!valid(data)) { return false; }
        var payload = data as Lang.Dictionary;
        if (now != null && payload["observedAt"] > now + CLOCK_TOLERANCE_SECONDS) { return false; }
        if (!valid(previous)) { return true; }
        var old = previous as Lang.Dictionary;
        if (now != null && old["observedAt"] > now + CLOCK_TOLERANCE_SECONDS) { return true; }
        return payload["observedAt"] >= old["observedAt"];
    }

    function validWindow(window, duration) {
        if (window == null) { return true; }
        if (!(window instanceof Lang.Dictionary)) { return false; }
        var quota = window["quotaRemaining"];
        var reset = window["resetsAt"];
        if (!(quota instanceof Lang.Number) && !(quota instanceof Lang.Float) && !(quota instanceof Lang.Double)) {
            return false;
        }
        return quota >= 0 && quota <= 1 &&
            window["durationSeconds"] == duration &&
            reset instanceof Lang.Number && reset > 0;
    }

    function valid(data) {
        if (!(data instanceof Lang.Dictionary)) { return false; }
        if (data["schemaVersion"] != 1 || !(data["observedAt"] instanceof Lang.Number) || data["observedAt"] <= 0) {
            return false;
        }
        if (!data.hasKey("weekly") || !data.hasKey("session")) { return false; }
        if (data["weekly"] == null && data["session"] == null) { return false; }
        if (!validWindow(data["weekly"], 604800) || !validWindow(data["session"], 18000)) { return false; }
        var windows = [data["weekly"], data["session"]];
        for (var i = 0; i < windows.size(); i += 1) {
            var window = windows[i] as Lang.Dictionary or Null;
            if (window != null && window["resetsAt"] > data["observedAt"] + window["durationSeconds"] + CLOCK_TOLERANCE_SECONDS) {
                return false;
            }
        }
        return true;
    }
}
