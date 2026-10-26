using Toybox.Graphics;
using Toybox.Lang;
using Toybox.Test;
using Toybox.WatchUi;

// These tests are excluded from regular builds by the Connect IQ compiler.
(:test)
class GaugeDrawingProbe {
    var arcs as Lang.Array<Lang.Array<Lang.Numeric>> = [];
    var rectangles as Lang.Array<Lang.Array<Lang.Numeric>> = [];
    var lines as Lang.Array<Lang.Array<Lang.Numeric>> = [];
    var color;
    var pen = 1;
    function initialize() {}
    function setColor(foreground, background) { color = foreground; }
    function setPenWidth(width) { pen = width; }
    function getFontHeight(font) { return 21; }
    function drawArc(x, y, radius, direction, start, end) {
        arcs.add([radius, start, end]);
    }
    function drawRectangle(x, y, width, height) {}
    function fillRectangle(x, y, width, height) { rectangles.add([color, x, y, width, height]); }
    function drawLine(x1, y1, x2, y2) { lines.add([color, pen]); }
    function drawText(x, y, font, text, justification) {}
}

(:test)
function emptyQuotaNeverDrawsFilledArc(logger) {
    var dc = new GaugeDrawingProbe();
    var view = new TokenWatchView();
    view.drawFiveHour(dc, new QuotaWindow(0.0, 0.5, MockQuotaProvider.FIVE_HOUR_SECONDS));
    Test.assertEqual(dc.arcs.size(), 2); // Only the two outlined edges.
    for (var i = 0; i < dc.arcs.size(); i += 1) {
        Test.assert(dc.arcs[i][1] != dc.arcs[i][2]);
    }
    return true;
}

(:test)
function fullQuotaIsOnlyASemicircle(logger) {
    var dc = new GaugeDrawingProbe();
    new TokenWatchView().drawFiveHour(dc, new QuotaWindow(1.0, 1.0, MockQuotaProvider.FIVE_HOUR_SECONDS));
    Test.assertEqual(dc.arcs.size(), 7); // Two edges and five fill radii.
    for (var i = 0; i < dc.arcs.size(); i += 1) {
        Test.assertEqual(dc.arcs[i][1], 180);
        Test.assertEqual(dc.arcs[i][2], 0);
    }
    return true;
}

(:test)
function markersKeepContrastAtBothEndsAndOverlap(logger) {
    var view = new TokenWatchView();
    var fractions = [0.0, 0.5, 1.0];
    for (var i = 0; i < fractions.size(); i += 1) {
        var window = new QuotaWindow(fractions[i], fractions[i], MockQuotaProvider.FIVE_HOUR_SECONDS);
        var dc = new GaugeDrawingProbe();
        view.drawFiveHour(dc, window);
        var halo = dc.lines[dc.lines.size() - 2];
        var spine = dc.lines[dc.lines.size() - 1];
        Test.assertEqual(halo[0], Graphics.COLOR_BLACK);
        Test.assertEqual(halo[1], 3);
        Test.assertEqual(spine[0], Graphics.COLOR_WHITE);
        Test.assertEqual(spine[1], 1);
        var bar = new GaugeDrawingProbe();
        view.drawSevenDay(bar, window);
        var barHalo = bar.rectangles[bar.rectangles.size() - 1];
        Test.assertEqual(barHalo[0], Graphics.COLOR_BLACK);
        Test.assertEqual(barHalo[3], 3);
        Test.assertEqual(bar.lines[0][0], Graphics.COLOR_WHITE);
    }
    return true;
}

(:test)
function renderEveryScenarioAndClockFont(logger) {
    // Use the device's actual rasterizer, not a desktop approximation.
    var bitmap = new Graphics.BufferedBitmap({:width => 176, :height => 176});
    var dc = bitmap.getDc();
    var view = new TokenWatchView();
    for (var scenario = 0; scenario <= MockQuotaProvider.UNDER_A_MINUTE; scenario += 1) {
        var snapshot = MockQuotaProvider.forScenario(scenario);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();
        view.drawSevenDay(dc, snapshot.sevenDay);
        view.drawFiveHour(dc, snapshot.fiveHour);
        view.drawBattery(dc);
    }
    var font = WatchUi.loadResource(Rez.Fonts.Clock);
    // Preserve the sleep-screen font's line height and original advances.
    Test.assertEqual(dc.getFontHeight(font), 58);
    Test.assertEqual(dc.getTextWidthInPixels("0:23", font), 111);
    Test.assertEqual(dc.getTextWidthInPixels("00:23", font), 143);
    var times = ["00:00", "11:11", "20:38", "23:59"];
    for (var i = 0; i < times.size(); i += 1) {
        dc.drawText(88, 112, font, times[i],
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        Test.assert(dc.getTextWidthInPixels(times[i], font) <= 164);
    }
    return true;
}

(:test)
function countdownRoundsLargestUnitWithoutNegativeZero(logger) {
    Test.assertEqual(ResetCountdown.format(390600), "-5d");
    Test.assertEqual(ResetCountdown.format(3480), "-58m");
    Test.assertEqual(ResetCountdown.format(86400), "-1d");
    Test.assertEqual(ResetCountdown.format(86399), "-24h");
    Test.assertEqual(ResetCountdown.format(3600), "-1h");
    Test.assertEqual(ResetCountdown.format(3599), "-60m");
    Test.assertEqual(ResetCountdown.format(4 * 86400 + 12 * 3600 - 1), "-4d");
    Test.assertEqual(ResetCountdown.format(4 * 86400 + 12 * 3600), "-5d");
    Test.assertEqual(ResetCountdown.format(4 * 3600 + 29 * 60), "-4h");
    Test.assertEqual(ResetCountdown.format(4 * 3600 + 30 * 60 - 1), "-4h");
    Test.assertEqual(ResetCountdown.format(4 * 3600 + 30 * 60), "-5h");
    Test.assertEqual(ResetCountdown.format(4 * 3600 + 59 * 60), "-5h");
    Test.assertEqual(ResetCountdown.format(89), "-1m");
    Test.assertEqual(ResetCountdown.format(90), "-2m");
    Test.assertEqual(ResetCountdown.format(60), "-1m");
    Test.assertEqual(ResetCountdown.format(59), "-<1m");
    Test.assertEqual(ResetCountdown.format(0), "0m");
    Test.assertEqual(ResetCountdown.format(-1), "0m");
    var example = MockQuotaProvider.forScenario(MockQuotaProvider.EXAMPLE);
    Test.assertEqual(ResetCountdown.format(example.fiveHour.secondsRemaining), "-3h");
    Test.assertEqual(ResetCountdown.format(example.sevenDay.secondsRemaining), "-5d");
    var snapshot = MockQuotaProvider.forScenario(MockQuotaProvider.RESET_SOON);
    Test.assertEqual(ResetCountdown.format(snapshot.fiveHour.secondsRemaining), "-58m");
    Test.assertEqual(ResetCountdown.format(snapshot.sevenDay.secondsRemaining), "-5d");
    return true;
}

(:test)
class QuotaFixtures {
static function payload() as Lang.Dictionary {
    return {
        "schemaVersion" => 1, "observedAt" => 1800000000,
        "session" => {"quotaRemaining" => 0.35, "durationSeconds" => 18000, "resetsAt" => 1800010800},
        "weekly" => {"quotaRemaining" => 0.65, "durationSeconds" => 604800, "resetsAt" => 1800390600}
    };
}

}

(:test)
function fullSessionFromStoredPayloadRenders(logger) {
    var data = {
        "schemaVersion" => 1, "observedAt" => 1792795512,
        "weekly" => {"quotaRemaining" => 0.9, "durationSeconds" => 604800, "resetsAt" => 1793382232},
        "session" => {"quotaRemaining" => 1, "durationSeconds" => 18000, "resetsAt" => 1792813512}
    };
    Test.assert(QuotaPayload.valid(data));
    var snapshot = LiveQuotaProvider.fromPayload(data, 1792795512);
    Test.assertEqual(snapshot.fiveHour.state, QuotaWindow.CURRENT);
    Test.assertEqual(snapshot.fiveHour.quotaRemaining, 1);
    Test.assertEqual(snapshot.fiveHour.secondsRemaining, 18000);
    Test.assertEqual(LiveQuotaProvider.label(snapshot.fiveHour), "-5h");
    Test.assertEqual(snapshot.sevenDay.state, QuotaWindow.CURRENT);
    var dc = new GaugeDrawingProbe();
    new TokenWatchView().drawFiveHour(dc, snapshot.fiveHour);
    Test.assertEqual(dc.arcs.size(), 7);
    return true;
}

(:test)
function liveCountdownAndMarkerAdvanceWithoutAnotherPoll(logger) {
    var data = QuotaFixtures.payload();
    var first = LiveQuotaProvider.fromPayload(data, 1800000000);
    var later = LiveQuotaProvider.fromPayload(data, 1800000300);
    Test.assertEqual(first.fiveHour.secondsRemaining, 10800);
    Test.assertEqual(later.fiveHour.secondsRemaining, 10500);
    Test.assert(later.fiveHour.periodRemaining < first.fiveHour.periodRemaining);
    Test.assertEqual(later.fiveHour.quotaRemaining, first.fiveHour.quotaRemaining);
    Test.assertEqual(LiveQuotaProvider.label(later.fiveHour), "-3h");
    return true;
}

(:test)
function resetDoesNotInventANewQuota(logger) {
    var snapshot = LiveQuotaProvider.fromPayload(QuotaFixtures.payload(), 1800010800);
    Test.assertEqual(snapshot.fiveHour.state, QuotaWindow.AWAITING_RESET);
    Test.assertEqual(LiveQuotaProvider.label(snapshot.fiveHour), "...");
    Test.assertEqual(snapshot.sevenDay.state, QuotaWindow.CURRENT);
    return true;
}

(:test)
function missingDataAndInvalidClockRemainUnknown(logger) {
    var data = QuotaFixtures.payload();
    data["session"] = null;
    var snapshot = LiveQuotaProvider.fromPayload(data, 1800000000);
    Test.assertEqual(snapshot.fiveHour.state, QuotaWindow.UNAVAILABLE);
    Test.assertEqual(LiveQuotaProvider.label(snapshot.fiveHour), "...");
    Test.assertEqual(snapshot.sevenDay.state, QuotaWindow.CURRENT);
    snapshot = LiveQuotaProvider.fromPayload(data, null);
    Test.assertEqual(snapshot.sevenDay.state, QuotaWindow.UNAVAILABLE);
    snapshot = LiveQuotaProvider.fromPayload(data, 1799999000);
    Test.assertEqual(snapshot.sevenDay.state, QuotaWindow.UNAVAILABLE);
    return true;
}

(:test)
function staleAgeUsesObservationRatherThanFetchTime(logger) {
    Test.assert(!LiveQuotaProvider.fromPayload(QuotaFixtures.payload(), 1800000899).stale);
    Test.assert(LiveQuotaProvider.fromPayload(QuotaFixtures.payload(), 1800000900).stale);
    return true;
}

(:test)
function malformedPayloadsAreRejected(logger) {
    Test.assert(!QuotaPayload.valid(null));
    Test.assert(!QuotaPayload.valid({"error" => "not found"}));
    var data = QuotaFixtures.payload();
    data["schemaVersion"] = 2;
    Test.assert(!QuotaPayload.valid(data));
    data = QuotaFixtures.payload();
    var weekly = data["weekly"] as Lang.Dictionary;
    weekly["quotaRemaining"] = 1.1;
    Test.assert(!QuotaPayload.valid(data));
    data = QuotaFixtures.payload();
    var session = data["session"] as Lang.Dictionary;
    session["durationSeconds"] = 300;
    Test.assert(!QuotaPayload.valid(data));
    return true;
}

(:test)
function cacheRejectsOldInvalidAndFutureResponses(logger) {
    var previous = QuotaFixtures.payload();
    var incoming = QuotaFixtures.payload();
    Test.assert(QuotaPayload.canReplace(null, incoming, 1800000000));
    Test.assert(QuotaPayload.canReplace("corrupt cache", incoming, 1800000000));
    Test.assert(!QuotaPayload.canReplace(previous, {"error" => "offline"}, 1800000000));
    previous["observedAt"] = 1800000300;
    Test.assert(!QuotaPayload.canReplace(previous, incoming, 1800000300));
    incoming["observedAt"] = 1800001000;
    Test.assert(!QuotaPayload.canReplace(previous, incoming, 1800000300));
    // A corrected collector clock can recover a cache stamped in the future.
    previous["observedAt"] = 1800001000;
    incoming["observedAt"] = 1800000300;
    Test.assert(QuotaPayload.canReplace(previous, incoming, 1800000300));
    return true;
}

(:test)
function missingSettingsRequireSetup(logger) {
    Test.assertEqual(QuotaConfig.source(null), QuotaConfig.LIVE);
    Test.assertEqual(QuotaConfig.source(0), QuotaConfig.LIVE);
    Test.assertEqual(QuotaConfig.source(1), QuotaConfig.MOCK);
    Test.assert(QuotaConfig.endpoint(null) == null);
    Test.assert(QuotaConfig.endpoint("") == null);
    Test.assert(QuotaConfig.endpoint(123) == null);
    Test.assertEqual(QuotaConfig.endpoint("https://example.com/quota"), "https://example.com/quota");
    return true;
}
