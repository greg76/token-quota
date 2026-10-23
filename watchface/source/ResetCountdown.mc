module ResetCountdown {
    const SECONDS_PER_MINUTE = 60;
    const SECONDS_PER_HOUR = 60 * SECONDS_PER_MINUTE;
    const SECONDS_PER_DAY = 24 * SECONDS_PER_HOUR;

    // Floor the largest whole unit. Never claim a reset has occurred early.
    function format(seconds) {
        if (seconds <= 0) { return "0m"; }
        if (seconds >= SECONDS_PER_DAY) {
            return "-" + (seconds / SECONDS_PER_DAY).toNumber().format("%d") + "d";
        }
        if (seconds >= SECONDS_PER_HOUR) {
            return "-" + (seconds / SECONDS_PER_HOUR).toNumber().format("%d") + "h";
        }
        if (seconds >= SECONDS_PER_MINUTE) {
            return "-" + (seconds / SECONDS_PER_MINUTE).toNumber().format("%d") + "m";
        }
        return "-<1m";
    }
}
