using Toybox.Application;
using Toybox.Background;
using Toybox.Communications;
using Toybox.Lang;
using Toybox.PersistedContent;
using Toybox.System;
using Toybox.Time;

(:background)
class QuotaService extends System.ServiceDelegate {
    function initialize() { ServiceDelegate.initialize(); }

    function onTemporalEvent() {
        var url = QuotaConfig.url();
        if (QuotaConfig.isMock() || url == null) {
            Background.exit(null);
            return;
        }
        Background.registerForTemporalEvent(new Time.Duration(QuotaPayload.POLL_SECONDS));
        Application.Storage.setValue(QuotaPayload.STATUS_KEY, "FETCH");
        Communications.makeWebRequest(url, {}, {
            :method => Communications.HTTP_REQUEST_METHOD_GET,
            :headers => {"Accept" => "application/json", "Cache-Control" => "no-cache", "User-Agent" => "TokenQuota/1.0"},
            :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
        }, method(:onResponse));
    }

    function onResponse(code as Lang.Number, data as Lang.Dictionary or Lang.String or Lang.ByteArray or PersistedContent.Iterator or Null) as Void {
        if (code == 200) {
            var previous = Application.Storage.getValue(QuotaPayload.STORAGE_KEY);
            if (!QuotaPayload.canReplace(previous, data, QuotaPayload.nowSeconds())) {
                Application.Storage.setValue(QuotaPayload.STATUS_KEY, QuotaPayload.valid(data) ? "TIME" : "DATA");
                Background.exit(null);
                return;
            }
            var payload = data as Lang.Dictionary;
            Application.Storage.setValue(QuotaPayload.STORAGE_KEY, payload);
            Application.Storage.setValue(QuotaPayload.STATUS_KEY, "OK");
            Background.exit(payload);
            return;
        }
        System.println("Quota fetch failed: " + code);
        Application.Storage.setValue(QuotaPayload.STATUS_KEY, "E" + code);
        Background.exit(null);
    }
}
