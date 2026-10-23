using Toybox.Graphics;
using Toybox.Lang;
using Toybox.Math;
using Toybox.System;
using Toybox.WatchUi;

class TokenWatchView extends WatchUi.WatchFace {
    const PROMPT_X = 8;
    const PROMPT_Y = 55;
    var clockFont;
    var promptFont;

    function initialize() {
        WatchFace.initialize();
        clockFont = WatchUi.loadResource(Rez.Fonts.Clock);
        promptFont = WatchUi.loadResource(Rez.Fonts.Prompt);
    }

    function onUpdate(dc) {
        dc.clearClip();
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();
        dc.setPenWidth(1);
        var quotas = LiveQuotaProvider.getSnapshot();
        drawSevenDay(dc, quotas.sevenDay);
        drawFiveHour(dc, quotas.fiveHour);
        if (!QuotaConfig.isMock() && QuotaConfig.url() == null) {
            dc.drawText(20, 8, Graphics.FONT_XTINY, "SETUP", Graphics.TEXT_JUSTIFY_LEFT);
        } else if (quotas.stale) {
            dc.drawText(8, 8, Graphics.FONT_XTINY, "!", Graphics.TEXT_JUSTIFY_LEFT);
        }
        var clock = System.getClockTime();
        var time = clock.hour.format("%02d") + ":" + clock.min.format("%02d");
        drawPrompt(dc, clock.sec);
        dc.drawText(88, 106, clockFont, time,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        drawBattery(dc);
    }

    function onPartialUpdate(dc) {
        var clock = System.getClockTime();
        var bounds = promptCursorBounds(dc);
        // Limit the always-on refresh to the single cursor glyph.
        dc.setClip(bounds[0], bounds[1], bounds[2], bounds[3]);
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.fillRectangle(bounds[0], bounds[1], bounds[2], bounds[3]);
        drawPromptCursor(dc, bounds[0], bounds[1], bounds[2], bounds[3], clock.sec);
    }

    function drawPrompt(dc, second) {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.drawText(PROMPT_X, PROMPT_Y, promptFont, "> What's next?", Graphics.TEXT_JUSTIFY_LEFT);
        var bounds = promptCursorBounds(dc);
        drawPromptCursor(dc, bounds[0], bounds[1], bounds[2], bounds[3], second);
    }

    function promptCursorBounds(dc) as Lang.Array<Lang.Numeric> {
        var prefixWidth = dc.getTextWidthInPixels("> ", promptFont);
        var cursorWidth = dc.getTextWidthInPixels("W", promptFont);
        return [PROMPT_X + prefixWidth, PROMPT_Y, cursorWidth, dc.getFontHeight(promptFont)];
    }

    function drawPromptCursor(dc, x, y, width, height, second) {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        if (second % 2 == 0) {
            dc.fillRectangle(x, y, width, height);
            dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_WHITE);
        }
        dc.drawText(x, y, promptFont, "W", Graphics.TEXT_JUSTIFY_LEFT);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
    }

    function drawSevenDay(dc, window) {
        // Entire bar and label stay left of the physical sub-display (x=113).
        var x = 8;
        var y = 36;
        var width = 88;
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.drawRectangle(x, y, width, 10);
        var fill = window.state == QuotaWindow.CURRENT ? (window.quotaRemaining * (width - 4)).toNumber() : 0;
        if (fill > 0) { dc.fillRectangle(x + 2, y + 2, fill, 6); }
        // Reserve a 5px gap above the marker, including the font's full line box.
        var labelY = y - 3 - 5 - dc.getFontHeight(Graphics.FONT_XTINY);
        dc.drawText(x + width - 1, labelY, Graphics.FONT_XTINY,
            LiveQuotaProvider.label(window), Graphics.TEXT_JUSTIFY_RIGHT);

        if (window.state != QuotaWindow.CURRENT) { return; }

        // A black halo and white spine remain visible over filled and empty areas.
        var marker = x + 2 + (window.periodRemaining * (width - 5)).toNumber();
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.fillRectangle(marker - 1, y - 3, 3, 16);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.drawLine(marker, y - 3, marker, y + 12);
    }

    function drawFiveHour(dc, window) {
        var box = WatchUi.getSubscreen();
        if (box == null) { return; }
        var cx = box.x + box.width / 2;
        var cy = box.y + box.height / 2 + 1;
        var outer = 23;
        var inner = 17;
        // Both gauges grow from left to right: 0% at left, 100% at right.
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.drawArc(cx, cy, outer, Graphics.ARC_CLOCKWISE, 180, 0);
        dc.drawArc(cx, cy, inner, Graphics.ARC_CLOCKWISE, 180, 0);
        dc.drawLine(cx - outer, cy, cx - inner, cy);
        dc.drawLine(cx + inner, cy, cx + outer, cy);
        var sweep = window.state == QuotaWindow.CURRENT ? (180 * window.quotaRemaining).toNumber() : 0;
        // Equal start/end angles mean a FULL CIRCLE in Garmin's API.
        if (sweep > 0) {
            for (var r = inner + 1; r < outer; r += 1) {
                dc.drawArc(cx, cy, r, Graphics.ARC_CLOCKWISE, 180, 180 - sweep);
            }
        }
        dc.drawText(cx, cy - 3, Graphics.FONT_XTINY, LiveQuotaProvider.label(window), Graphics.TEXT_JUSTIFY_CENTER);
        if (window.state != QuotaWindow.CURRENT) { return; }
        var angle = Math.PI * (1.0 - window.periodRemaining);
        var x1 = cx + Math.cos(angle) * (inner - 3);
        var y1 = cy - Math.sin(angle) * (inner - 3);
        var x2 = cx + Math.cos(angle) * (outer + 3);
        var y2 = cy - Math.sin(angle) * (outer + 3);
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.setPenWidth(3);
        dc.drawLine(x1, y1, x2, y2);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.setPenWidth(1);
        dc.drawLine(x1, y1, x2, y2);
    }

    function drawBattery(dc) {
        var stats = System.getSystemStats();
        var days = "--d";
        if ((stats has :batteryInDays) && stats.batteryInDays != null && stats.batteryInDays >= 0) {
            days = stats.batteryInDays.toNumber().format("%d") + "d";
        }
        var textWidth = dc.getTextWidthInPixels(days, Graphics.FONT_XTINY);
        var left = (176 - (24 + 6 + textWidth)) / 2;
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.setPenWidth(1);
        dc.drawRectangle(left, 150, 22, 15);
        dc.fillRectangle(left + 22, 155, 2, 5);
        var level = (stats.battery * 18 / 100).toNumber();
        if (level > 0) { dc.fillRectangle(left + 2, 152, level, 11); }
        dc.drawText(left + 30, 147, Graphics.FONT_XTINY, days, Graphics.TEXT_JUSTIFY_LEFT);
    }
}
