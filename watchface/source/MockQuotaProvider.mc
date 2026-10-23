using Toybox.Application;
using Toybox.Math;

// Fractions are remaining quota and remaining period, always in that order.
// Rendering consumes this model; a future provider can supply the same model.
class QuotaWindow {
    enum State { CURRENT, UNAVAILABLE, AWAITING_RESET }
    var state = CURRENT;
    var quotaRemaining;
    var periodRemaining;
    var secondsRemaining;
    function initialize(quota, period, durationSeconds) {
        quotaRemaining = quota;
        periodRemaining = period;
        secondsRemaining = Math.round(period * durationSeconds).toNumber();
    }
}

class QuotaSnapshot {
    var stale = false;
    var fiveHour;
    var sevenDay;
    function initialize(five, seven) {
        fiveHour = five;
        sevenDay = seven;
    }
}

module MockQuotaProvider {
    const FIVE_HOUR_SECONDS = 5 * 60 * 60;
    const SEVEN_DAY_SECONDS = 7 * 24 * 60 * 60;
    enum Scenario { EXAMPLE, EMPTY, FULL, ON_PACE, AHEAD, BEHIND, PERIOD_START, PERIOD_END, RESET_SOON, UNDER_A_MINUTE }

    function getSnapshot() {
        var scenario = Application.Properties.getValue("MockScenario");
        return forScenario(scenario);
    }

    // All mock values live here. No clock or battery values are mocked.
    function forScenario(scenario) {
        switch (scenario) {
            case EMPTY: return pair(0.0, 0.6, 0.0, 0.45);
            case FULL: return pair(1.0, 0.6, 1.0, 0.45);
            case ON_PACE: return pair(0.5, 0.5, 0.5, 0.5);
            case AHEAD: return pair(0.8, 0.4, 0.8, 0.4);
            case BEHIND: return pair(0.25, 0.7, 0.25, 0.7);
            case PERIOD_START: return pair(1.0, 1.0, 1.0, 1.0);
            case PERIOD_END: return pair(0.0, 0.0, 0.0, 0.0);
            case RESET_SOON: return pair(0.35, 3480.0 / FIVE_HOUR_SECONDS,
                0.65, 390600.0 / SEVEN_DAY_SECONDS);
            case UNDER_A_MINUTE: return pair(0.1, 30.0 / FIVE_HOUR_SECONDS,
                0.1, 30.0 / SEVEN_DAY_SECONDS);
        }
        return pair(0.35, 0.60, 0.65, 390600.0 / SEVEN_DAY_SECONDS);
    }

    function pair(fiveQuota, fivePeriod, sevenQuota, sevenPeriod) {
        return new QuotaSnapshot(new QuotaWindow(fiveQuota, fivePeriod, FIVE_HOUR_SECONDS),
            new QuotaWindow(sevenQuota, sevenPeriod, SEVEN_DAY_SECONDS));
    }
}
