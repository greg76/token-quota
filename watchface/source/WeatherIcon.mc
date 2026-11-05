using Toybox.Graphics;
using Toybox.Weather;

// 16x16 symbols from weather-pixel-icons-solid.pxd. Pixel data and draw() are generated
// by scripts/generate-weather-icons.py; condition mapping is maintained here.
module WeatherIcon {
    enum Kind { UNKNOWN, SUN, PARTLY_CLOUDY, CLOUD, RAIN, SNOW, MIX, STORM, FOG, WIND, MOON, PARTLY_CLOUDY_NIGHT, RAIN_HEAVY }

    function kind(condition) {
        switch (condition) {
            case Weather.CONDITION_CLEAR:
            case Weather.CONDITION_FAIR: return SUN;
            case Weather.CONDITION_PARTLY_CLOUDY:
            case Weather.CONDITION_PARTLY_CLEAR:
            case Weather.CONDITION_MOSTLY_CLEAR:
            case Weather.CONDITION_THIN_CLOUDS: return PARTLY_CLOUDY;
            case Weather.CONDITION_MOSTLY_CLOUDY:
            case Weather.CONDITION_CLOUDY: return CLOUD;
            case Weather.CONDITION_RAIN:
            case Weather.CONDITION_LIGHT_RAIN:
            case Weather.CONDITION_SCATTERED_SHOWERS:
            case Weather.CONDITION_LIGHT_SHOWERS:
            case Weather.CONDITION_CHANCE_OF_SHOWERS:
            case Weather.CONDITION_CLOUDY_CHANCE_OF_RAIN:
            case Weather.CONDITION_DRIZZLE:
            case Weather.CONDITION_UNKNOWN_PRECIPITATION: return RAIN;
            case Weather.CONDITION_HEAVY_RAIN:
            case Weather.CONDITION_SHOWERS:
            case Weather.CONDITION_HEAVY_SHOWERS: return RAIN_HEAVY;
            case Weather.CONDITION_SNOW:
            case Weather.CONDITION_LIGHT_SNOW:
            case Weather.CONDITION_HEAVY_SNOW:
            case Weather.CONDITION_CHANCE_OF_SNOW:
            case Weather.CONDITION_CLOUDY_CHANCE_OF_SNOW:
            case Weather.CONDITION_FLURRIES: return SNOW;
            case Weather.CONDITION_WINTRY_MIX:
            case Weather.CONDITION_LIGHT_RAIN_SNOW:
            case Weather.CONDITION_HEAVY_RAIN_SNOW:
            case Weather.CONDITION_RAIN_SNOW:
            case Weather.CONDITION_CHANCE_OF_RAIN_SNOW:
            case Weather.CONDITION_CLOUDY_CHANCE_OF_RAIN_SNOW:
            case Weather.CONDITION_HAIL:
            case Weather.CONDITION_ICE:
            case Weather.CONDITION_FREEZING_RAIN:
            case Weather.CONDITION_SLEET:
            case Weather.CONDITION_ICE_SNOW: return MIX;
            case Weather.CONDITION_THUNDERSTORMS:
            case Weather.CONDITION_SCATTERED_THUNDERSTORMS:
            case Weather.CONDITION_CHANCE_OF_THUNDERSTORMS: return STORM;
            case Weather.CONDITION_FOG:
            case Weather.CONDITION_HAZY:
            case Weather.CONDITION_HAZE:
            case Weather.CONDITION_MIST:
            case Weather.CONDITION_DUST:
            case Weather.CONDITION_SMOKE:
            case Weather.CONDITION_SAND:
            case Weather.CONDITION_SANDSTORM:
            case Weather.CONDITION_VOLCANIC_ASH: return FOG;
            case Weather.CONDITION_WINDY:
            case Weather.CONDITION_TORNADO:
            case Weather.CONDITION_SQUALL:
            case Weather.CONDITION_HURRICANE:
            case Weather.CONDITION_TROPICAL_STORM: return WIND;
        }
        return UNKNOWN;
    }

    function symbolForTime(condition, night) {
        var symbol = kind(condition);
        if (!night) { return symbol; }
        if (symbol == SUN) { return MOON; }
        if (symbol == PARTLY_CLOUDY) { return PARTLY_CLOUDY_NIGHT; }
        return symbol;
    }

    const WIDTH = 16;
    const HEIGHT = 16;
    const PIXELS = [
        [0, 0, 448, 544, 1040, 1040, 1024, 1024, 512, 256, 128, 128, 128, 0, 128, 0], // UNKNOWN
        [0, 256, 256, 8456, 4112, 896, 1984, 4064, 61422, 4064, 1984, 896, 4112, 8456, 256, 256], // SUN
        [32, 546, 260, 112, 3832, 8059, 16264, 16240, 32504, 65532, 65532, 65532, 65528, 32752, 0, 0], // PARTLY_CLOUDY
        [0, 0, 0, 0, 1792, 3968, 8128, 8120, 16252, 32766, 32766, 32766, 32764, 16376, 0, 0], // CLOUD
        [1792, 3968, 8128, 8120, 16252, 32766, 32766, 32766, 32764, 16376, 0, 2184, 10920, 8736, 0, 0], // RAIN
        [1792, 3968, 8128, 8120, 16252, 32766, 32766, 32766, 32764, 16376, 0, 4226, 528, 8256, 1028, 256], // SNOW
        [1792, 3968, 8128, 8120, 16252, 32766, 32766, 32766, 32764, 16376, 0, 1156, 16466, 520, 8192, 2048], // MIX
        [1792, 3968, 8128, 8120, 16252, 32766, 32766, 32766, 32764, 16376, 0, 256, 128, 960, 256, 128], // STORM
        [1792, 3968, 8128, 8120, 16252, 32766, 32766, 32766, 32764, 16376, 0, 7152, 0, 16224, 0, 7152], // FOG
        [0, 0, 192, 288, 6272, 9343, 4096, 4092, 0, 8176, 8192, 18942, 12800, 1152, 768, 0], // WIND
        [0, 0, 3840, 1984, 2016, 992, 1008, 1008, 1008, 1008, 1008, 992, 2016, 1984, 3840, 0], // MOON
        [0, 112, 120, 60, 1852, 4028, 8132, 8120, 16252, 32766, 32766, 32766, 32764, 16376, 0, 0], // PARTLY_CLOUDY_NIGHT
        [1792, 3968, 8128, 8120, 16252, 32766, 32766, 32766, 32764, 16376, 0, 8456, 5284, 528, 0, 0], // RAIN_HEAVY
    ];

    function draw(dc, x, y, condition) {
        drawSymbol(dc, x, y, kind(condition));
    }

    function drawSymbol(dc, x, y, symbol) {
        var rows = PIXELS[symbol];
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        // Draw horizontal runs at native resolution without resampling.
        for (var row = 0; row < HEIGHT; row += 1) {
            var column = 0;
            while (column < WIDTH) {
                if ((rows[row] & (1 << column)) == 0) {
                    column += 1;
                    continue;
                }
                var start = column;
                while (column < WIDTH && (rows[row] & (1 << column)) != 0) {
                    column += 1;
                }
                dc.fillRectangle(x + start, y + row, column - start, 1);
            }
        }
    }
}
