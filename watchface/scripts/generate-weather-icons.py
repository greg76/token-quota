#!/usr/bin/env python3
"""Export the 14×16 weather-pixel-icons.pxd cells to Monkey C and a preview.

Requires Pillow only when regenerating. Normal builds use the checked-in output.
The Pixelmator document uses black ink on white; the watch uses white on black.
"""
from pathlib import Path
import sqlite3
import struct
import zipfile
import zlib

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
WIDTH, HEIGHT = 14, 16
# Cell order in the source document, from left to right.
CELLS = [
    'UNKNOWN', 'RAIN', 'RAIN_HEAVY', 'SNOW', 'MIX', 'STORM', 'FOG',
    'CLOUD', 'PARTLY_CLOUDY', 'PARTLY_CLOUDY_NIGHT', 'SUN', 'MOON', 'WIND',
]

with zipfile.ZipFile(ROOT / 'weather-pixel-icons.pxd') as archive:
    database = sqlite3.connect(':memory:')
    database.deserialize(archive.read('metadata.info'))
    sheet = Image.new('RGBA', (WIDTH * len(CELLS), HEIGHT), 'white')
    layers = database.execute(
        'SELECT id, identifier FROM document_layers ORDER BY index_at_parent DESC'
    ).fetchall()
    for layer_id, identifier in layers:
        info = dict(database.execute(
            'SELECT key, value FROM layer_info WHERE layer_id = ?', (layer_id,)
        ))
        name_length = struct.unpack_from('<I', info['name'], 12)[0]
        name = info['name'][16:16 + name_length].decode()
        if name == 'Background':
            continue
        data = archive.read('data/' + identifier)
        assert data[:16] == b'PTBitmapBuffer__'
        width, height, stride, compression, format_length = struct.unpack_from('<5I', data, 28)
        assert stride == width * 4 and compression == 1
        pixels = zlib.decompress(data[56 + format_length:], -15)
        assert len(pixels) == stride * height
        layer = Image.frombytes('RGBA', (width, height), pixels)
        # Pixelmator positions are in points, with two pixels per point.
        x, y = struct.unpack('>dd', info['position'][12:])
        left, top = x * 2 - width / 2, y * 2 - height / 2
        assert left.is_integer() and top.is_integer()
        sheet.alpha_composite(layer, (int(left), int(top)))
    database.close()

icons = {}
for index, name in enumerate(CELLS):
    cell = sheet.crop((index * WIDTH, 0, (index + 1) * WIDTH, HEIGHT)).convert('RGB')
    # Preserve the source's pixel grid; resolve faint alpha edges to 1-bit ink.
    icons[name] = [sum(1 << x for x in range(WIDTH)
                       if cell.getpixel((x, y))[0] < 128) for y in range(HEIGHT)]

source = ROOT / 'source/WeatherIcon.mc'
text = source.read_text().split('    const WIDTH =')[0].split('    const PIXELS =')[0]
text += f'    const WIDTH = {WIDTH};\n    const HEIGHT = {HEIGHT};\n'
text += '    const PIXELS = [\n'
# Match the existing enum order, which also includes the new heavy-rain symbol.
order = ['UNKNOWN', 'SUN', 'PARTLY_CLOUDY', 'CLOUD', 'RAIN', 'SNOW', 'MIX',
         'STORM', 'FOG', 'WIND', 'MOON', 'PARTLY_CLOUDY_NIGHT', 'RAIN_HEAVY']
for name in order:
    text += '        [' + ', '.join(map(str, icons[name])) + '], // ' + name + '\n'
text += '''    ];

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
'''
source.write_text(text)

preview = Image.new('RGB', (700, 580), '#202020')
draw = ImageDraw.Draw(preview)
draw.text((16, 12), 'Weather icons: 14 x 16 pixels | actual size + 8x pixel view', fill='white')
for index, name in enumerate(CELLS):
    x, y = 16 + index % 5 * 138, 42 + index // 5 * 178
    icon = Image.new('1', (WIDTH, HEIGHT))
    for row, mask in enumerate(icons[name]):
        for column in range(WIDTH):
            icon.putpixel((column, row), bool(mask & (1 << column)))
    preview.paste(icon.convert('RGB'), (x, y + 18))
    preview.paste(icon.resize((WIDTH * 8, HEIGHT * 8), Image.Resampling.NEAREST).convert('RGB'),
                  (x, y + 40))
    draw.text((x, y), name.replace('_', ' '), fill='white')
output = ROOT / 'weather-icons.png'
preview.save(output)
print(output)
