using Toybox.Position;
using Toybox.System;
using Toybox.Time;
using Toybox.Weather;

module WeatherDaylight {
    // Approximate local hours, used only when solar times cannot be obtained.
    const FALLBACK_SUNRISE_HOUR = 6;
    const FALLBACK_SUNSET_HOUR = 18;

    function isNight(conditions) {
        var now = Time.now();
        var location = conditions == null ? null : conditions.observationLocationPosition;
        // Reading the last fix does not start GPS acquisition.
        if (location == null) { location = Position.getInfo().position; }
        var sunrise = null;
        var sunset = null;
        if (location != null) {
            sunrise = Weather.getSunrise(location, now);
            sunset = Weather.getSunset(location, now);
        }
        return nightForTimes(System.getClockTime().hour, now.value(),
            sunrise == null ? null : sunrise.value(),
            sunset == null ? null : sunset.value());
    }

    function nightForTimes(localHour, now, sunrise, sunset) {
        if (sunrise == null || sunset == null || sunrise == sunset) {
            return localHour < FALLBACK_SUNRISE_HOUR || localHour >= FALLBACK_SUNSET_HOUR;
        }
        return outsideDaylight(now, sunrise, sunset);
    }

    function outsideDaylight(now, sunrise, sunset) {
        if (sunrise < sunset) {
            return now < sunrise || now >= sunset;
        }
        // The daylight interval can cross midnight in the API's UTC date.
        return now >= sunset && now < sunrise;
    }
}
