using Toybox.Application;
using Toybox.Lang;

(:background)
module QuotaConfig {
    enum Source { LIVE, MOCK }

    function source(value) { return value == MOCK ? MOCK : LIVE; }

    function isMock() {
        return source(Application.Properties.getValue("DataSource")) == MOCK;
    }

    function endpoint(value) {
        if (value instanceof Lang.String && value.length() > 0) { return value; }
        return null;
    }

    function url() { return endpoint(Application.Properties.getValue("QuotaUrl")); }
}
