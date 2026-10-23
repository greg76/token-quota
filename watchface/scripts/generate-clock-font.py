#!/usr/bin/env python3
"""Regenerate the checked-in clock font. Requires Pillow; normal builds do not."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / 'assets/fonts/RobotoCondensed.ttf'
DESTINATION = ROOT / 'resources/fonts'
CHARACTERS = '0123456789:'
MAX_WIDTH = 148
MAX_HEIGHT = 49

# Use the largest original font size that fits; do not stretch the glyphs.
for size in range(200, 11, -1):
    font = ImageFont.truetype(str(SOURCE), size)
    font.set_variation_by_axes([700])  # Roboto Condensed Bold
    boxes = [font.getbbox(char) for char in CHARACTERS]
    top = min(box[1] for box in boxes)
    bottom = max(box[3] for box in boxes)
    advances = {char: round(font.getlength(char)) for char in CHARACTERS}
    if 4 * max(advances[c] for c in '0123456789') + advances[':'] <= MAX_WIDTH and bottom - top <= MAX_HEIGHT:
        break
else:
    raise ValueError('No clock font size fits')

height = bottom - top
atlas = Image.new('L', (512, 128), 0)
drawing = ImageDraw.Draw(atlas)
records = []
x = 0
for char, box in zip(CHARACTERS, boxes):
    width = box[2] - box[0]
    drawing.text((x - box[0], -top), char, font=font, fill=255)
    records.append(f'char id={ord(char)} x={x} y=0 width={width} height={height} '
                   f'xoffset={box[0]} yoffset=0 xadvance={advances[char]} page=0 chnl=15')
    x += width + 2
# Only black and white pixels, without dithering or antialiasing on the device.
atlas = atlas.point(lambda value: 255 if value >= 128 else 0)
DESTINATION.mkdir(parents=True, exist_ok=True)
atlas.save(DESTINATION / 'clock.png')
header = [f'info face="Token Clock" size={size} bold=1 italic=0 charset="" unicode=1 stretchH=100 smooth=0 aa=1 padding=0,0,0,0 spacing=0,0 outline=0',
          f'common lineHeight={height} base={height} scaleW=512 scaleH=128 pages=1 packed=0',
          'page id=0 file="clock.png"', f'chars count={len(CHARACTERS)}']
(DESTINATION / 'clock.fnt').write_text('\n'.join(header + records) + '\n')
print(f'Generated {size}px source size, {height}px visible height, '
      f'{4 * advances["0"] + advances[":"]}px clock width')
