#!/usr/bin/env python3
"""Export the Garmin sleep clock's exact bitmap glyphs. Requires Pillow."""
import argparse
import hashlib
import struct
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SOURCE_NAME = 'FNT_006B458400_0000_GARMIN_65.cft'
SOURCE_SHA256 = '594bb755a78d7b5eb3fa609e74dc528c7b5cfd6f640f9e5b6624542bd1a18b81'
DEFAULT_SOURCE = Path.home() / 'Library/Application Support/Garmin/ConnectIQ/Fonts' / SOURCE_NAME
CHARACTERS = '0123456789:'

# CFT layout and RLE decoding adapted from Mark Williams's cftinfo.ts:
# https://github.com/markw65/monkeyc-optimizer/blob/main/src/cftinfo.ts
# See cft-parser-LICENSE.txt for the MIT license. This export supports only the
# pinned, one-bit CFT above, rather than every Garmin font format.
def decode_glyph(data, offset, size):
    bit_position = offset * 8

    def read_bits(count):
        nonlocal bit_position
        value = 0
        for bit in range(count):
            value |= ((data[bit_position // 8] >> (bit_position % 8)) & 1) << bit
            bit_position += 1
        return value

    run_bits = 1
    while read_bits(1) == 0:
        run_bits += 1
    chunk_bits = read_bits(5) + 1
    escape = read_bits(chunk_bits)
    output = 0
    output_bits = 0
    previous = None
    while output_bits // 8 < size:
        chunk = read_bits(chunk_bits)
        count = 1
        if chunk == escape:
            run = read_bits(run_bits)
            if run:
                if previous is None:
                    raise ValueError('CFT run has no preceding value')
                chunk = previous
                count = run + 1
            else:
                previous = chunk
        else:
            previous = chunk
        for _ in range(count):
            output |= chunk << output_bits
            output_bits += chunk_bits
    return output.to_bytes((output_bits + 7) // 8, 'little')[:size]


def load_glyphs(source):
    data = source.read_bytes()
    if hashlib.sha256(data).hexdigest() != SOURCE_SHA256:
        raise ValueError(f'{source} does not match the verified Garmin sleep font')
    cmap, info, pixels = struct.unpack_from('>III', data, 8)
    height = struct.unpack_from('>H', data, 22)[0]
    group_count = struct.unpack_from('>I', data, cmap + 12)[0]
    glyphs = {}
    for group in range(group_count):
        first, last, first_glyph = struct.unpack_from('>III', data, cmap + 16 + group * 12)
        for char in CHARACTERS:
            code = ord(char)
            if not first <= code <= last:
                continue
            word = struct.unpack_from('>I', data, info + (first_glyph + code - first) * 4)[0]
            width = word & 255
            offset = (((word >> 16) & 65535) + ((word & 65280) << 8)) & 0x7fffff
            stride = (width + 7) // 8
            raw = decode_glyph(data, pixels + offset, stride * height)
            glyph = Image.new('L', (width, height))
            for y in range(height):
                for x in range(width):
                    glyph.putpixel((x, y), 255 * ((raw[y * stride + x // 8] >> (x % 8)) & 1))
            glyphs[char] = glyph
    if set(glyphs) != set(CHARACTERS):
        raise ValueError('Source font is missing clock glyphs')
    return glyphs


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path, default=DEFAULT_SOURCE, help='Path to the verified Garmin .cft')
    args = parser.parse_args()
    glyphs = load_glyphs(args.source)
    boxes = {char: glyph.getbbox() for char, glyph in glyphs.items()}
    top = min(box[1] for box in boxes.values())
    bottom = max(box[3] for box in boxes.values())
    height = bottom - top
    atlas = Image.new('L', (512, 64))
    records = []
    x = 0
    for char in CHARACTERS:
        glyph = glyphs[char]
        box = boxes[char]
        crop = glyph.crop(box)
        atlas.paste(crop, (x, 0))
        records.append(f'char id={ord(char)} x={x} y=0 width={crop.width} height={crop.height} '
                       f'xoffset={box[0]} yoffset={box[1] - top} xadvance={glyph.width} page=0 chnl=15')
        x += crop.width + 2
    destination = ROOT / 'resources/fonts'
    destination.mkdir(parents=True, exist_ok=True)
    atlas.save(destination / 'clock.png')
    header = [f'info face="Garmin Sleep Clock" size={height} bold=1 italic=0 charset="" unicode=1 stretchH=100 smooth=0 aa=1 padding=0,0,0,0 spacing=0,0 outline=0',
              f'common lineHeight={height} base={height} scaleW=512 scaleH=64 pages=1 packed=0',
              'page id=0 file="clock.png"', f'chars count={len(CHARACTERS)}']
    (destination / 'clock.fnt').write_text('\n'.join(header + records) + '\n')
    print(f'Exported {height}px visible height, '
          f'{4 * glyphs["0"].width + glyphs[":"].width}px four-digit clock width')


if __name__ == '__main__':
    main()
