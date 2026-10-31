using Toybox.Graphics;
using Toybox.Weather;

// 14x16 symbols from weather-pixel-icons.pxd. Pixel data and draw() are generated
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

    const WIDTH = 14;
    const HEIGHT = 16;
    const PIXELS = [
        [0, 0, 224, 272, 520, 520, 512, 512, 256, 128, 64, 64, 64, 0, 64, 0], // UNKNOWN
        [0, 0, 0, 64, 1092, 520, 224, 272, 3350, 272, 224, 520, 1092, 64, 0, 0], // SUN
        [0, 0, 0, 32, 546, 260, 112, 904, 1099, 2096, 2056, 4100, 8194, 8194, 8196, 8184], // PARTLY_CLOUDY
        [0, 0, 0, 448, 544, 1048, 1028, 2050, 4097, 4097, 4098, 4092, 0, 0, 0, 0], // CLOUD
        [0, 0, 448, 544, 1048, 1028, 2050, 4097, 4097, 4098, 4092, 0, 136, 680, 544, 0], // RAIN
        [448, 4640, 1048, 1028, 2306, 4097, 4097, 4098, 4092, 0, 272, 4096, 68, 1024, 272, 0], // SNOW
        [448, 544, 1048, 1028, 2050, 4097, 4097, 4098, 4092, 0, 264, 4132, 16, 1024, 256, 0], // MIX
        [448, 544, 1048, 1028, 2050, 4097, 4097, 4098, 4092, 0, 128, 64, 480, 128, 64, 0], // STORM
        [448, 544, 1048, 1028, 2050, 4097, 4097, 4098, 4076, 0, 1788, 0, 4056, 0, 1788, 0], // FOG
        [0, 0, 0, 96, 144, 3136, 4670, 2048, 2040, 0, 252, 256, 576, 384, 0, 0], // WIND
        [0, 0, 0, 896, 608, 272, 272, 136, 136, 136, 272, 272, 608, 896, 0, 0], // MOON
        [0, 0, 0, 28, 18, 9, 9, 465, 545, 1050, 1028, 2050, 4097, 4097, 4098, 4092], // PARTLY_CLOUDY_NIGHT
        [0, 0, 448, 544, 1048, 1028, 2050, 4097, 4097, 4098, 4092, 0, 264, 1188, 528, 0], // RAIN_HEAVY
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
