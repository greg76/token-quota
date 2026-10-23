using Toybox.Application;
using Toybox.Lang;

module LiveQuotaProvider {
    function unknownWindow() {
        var window = new QuotaWindow(0.0, 0.0, 1);
        window.state = QuotaWindow.UNAVAILABLE;
        return window;
    }

    function fromWindow(data as Lang.Dictionary or Null, now) {
        if (data == null || now == null) { return unknownWindow(); }
        var seconds = data["resetsAt"] - now;
        if (seconds < 0) { seconds = 0; }
        var period = seconds.toFloat() / data["durationSeconds"];
        if (period > 1.0) { period = 1.0; }
        var window = new QuotaWindow(data["quotaRemaining"], period, data["durationSeconds"]);
        window.secondsRemaining = seconds;
        if (seconds == 0) { window.state = QuotaWindow.AWAITING_RESET; }
        return window;
    }

    function fromPayload(data, now) {
        if (!QuotaPayload.valid(data) || now == null) {
            return new QuotaSnapshot(unknownWindow(), unknownWindow());
        }
        var payload = data as Lang.Dictionary;
        if (payload["observedAt"] > now + QuotaPayload.CLOCK_TOLERANCE_SECONDS) {
            return new QuotaSnapshot(unknownWindow(), unknownWindow());
        }
        var snapshot = new QuotaSnapshot(fromWindow(payload["session"], now), fromWindow(payload["weekly"], now));
        snapshot.stale = now - payload["observedAt"] >= QuotaPayload.STALE_SECONDS;
        return snapshot;
    }

    function getSnapshot() {
        if (QuotaConfig.isMock()) { return MockQuotaProvider.getSnapshot(); }
        if (QuotaConfig.url() == null) { return fromPayload(null, null); }
        return fromPayload(Application.Storage.getValue(QuotaPayload.STORAGE_KEY), QuotaPayload.nowSeconds());
    }

    function label(window) {
        if (window.state != QuotaWindow.CURRENT) { return "..."; }
        return ResetCountdown.format(window.secondsRemaining);
    }
}
