using Toybox.Application;
using Toybox.Background;
using Toybox.Time;
using Toybox.WatchUi;

(:background)
class TokenWatchApp extends Application.AppBase {
    function initialize() { AppBase.initialize(); }
    function getInitialView() {
        configurePolling();
        return [new TokenWatchView()];
    }
    function configurePolling() {
        if (QuotaConfig.isMock() || QuotaConfig.url() == null) {
            Background.deleteTemporalEvent();
            return;
        }
        // Fetch immediately on first install, or as soon as Garmin permits.
        // Reopening the face must not restart a five-minute waiting period.
        var last = Background.getLastTemporalEventTime();
        var next = last == null ? Time.now() : last.add(new Time.Duration(QuotaPayload.POLL_SECONDS));
        Background.registerForTemporalEvent(next);
    }
    function getServiceDelegate() { return [new QuotaService()]; }
    function onBackgroundData(data) { WatchUi.requestUpdate(); }
    function onSettingsChanged() {
        // A different URL may belong to a different account.
        Application.Storage.deleteValue(QuotaPayload.STORAGE_KEY);
        Application.Storage.deleteValue(QuotaPayload.STATUS_KEY);
        configurePolling();
        WatchUi.requestUpdate();
    }
}
