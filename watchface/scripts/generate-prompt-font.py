#!/usr/bin/env python3
"""Generate the prompt's original 5×7 monospace glyphs. Requires Pillow."""
from pathlib import Path
from PIL import Image

DESTINATION = Path(__file__).resolve().parent.parent / 'resources/fonts'
GLYPHS = {
    ' ': ['00000'] * 7,
    '>': ['00000', '10000', '01000', '00100', '01000', '10000', '00000'],
    'W': ['10001', '10001', '10001', '10101', '10101', '11011', '10001'],
    'h': ['10000', '10000', '10110', '11001', '10001', '10001', '10001'],
    'a': ['00000', '00000', '01110', '00001', '01111', '10001', '01111'],
    't': ['00100', '00100', '11111', '00100', '00100', '00101', '00010'],
    "'": ['00100', '00100', '01000', '00000', '00000', '00000', '00000'],
    's': ['00000', '00000', '01111', '10000', '01110', '00001', '11110'],
    'n': ['00000', '00000', '10110', '11001', '10001', '10001', '10001'],
    'e': ['00000', '00000', '01110', '10001', '11111', '10000', '01110'],
    'x': ['00000', '00000', '10001', '01010', '00100', '01010', '10001'],
    '?': ['01110', '10001', '00001', '00010', '00100', '00000', '00100'],
}

atlas = Image.new('L', (128, 16), 0)
records = []
for index, (character, rows) in enumerate(GLYPHS.items()):
    left = index * 6
    for y, row in enumerate(rows):
        for x, pixel in enumerate(row):
            if pixel == '1':
                atlas.putpixel((left + x, y + 1), 255)
    records.append(f'char id={ord(character)} x={left} y=0 width=6 height=9 '
                   'xoffset=0 yoffset=0 xadvance=6 page=0 chnl=15')

atlas.save(DESTINATION / 'prompt.png')
header = ['info face="Token Terminal" size=9 bold=0 italic=0 charset="" unicode=1 stretchH=100 smooth=0 aa=1 padding=0,0,0,0 spacing=0,0 outline=0',
          'common lineHeight=9 base=8 scaleW=128 scaleH=16 pages=1 packed=0',
          'page id=0 file="prompt.png"', f'chars count={len(GLYPHS)}']
(DESTINATION / 'prompt.fnt').write_text('\n'.join(header + records) + '\n')
