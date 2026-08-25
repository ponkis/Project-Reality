#!/usr/bin/env python3

import argparse
import struct
from pathlib import Path

from PIL import Image


RESOURCE_TYPE_TEXTURE = 0x4F544558
TEXTURE_TYPE_RGBA16 = 2
RESOURCE_HEADER_SIZE = 0x40


def scale_8_to_5(value: int) -> int:
    """Match Torch/n64graphics RGBA16 quantization exactly."""
    return ((value + 4) * 0x1F) // 0xFF


def encode_rgba16(image: Image.Image) -> bytes:
    encoded = bytearray()

    for red, green, blue, alpha in image.convert("RGBA").getdata():
        pixel = (
            (scale_8_to_5(red) << 11)
            | (scale_8_to_5(green) << 6)
            | (scale_8_to_5(blue) << 1)
            | (1 if alpha else 0)
        )
        encoded.extend(pixel.to_bytes(2, byteorder="big"))

    return bytes(encoded)


def build_otex(image: Image.Image) -> bytes:
    texture_data = encode_rgba16(image)
    header = struct.pack(
        "<4BIIQIQI",
        0,
        0,
        0,
        0,
        RESOURCE_TYPE_TEXTURE,
        0,
        0xDEADBEEFDEADBEEF,
        0,
        0,
        0,
    )
    header += bytes(RESOURCE_HEADER_SIZE - len(header))
    texture_header = struct.pack(
        "<IIII",
        TEXTURE_TYPE_RGBA16,
        image.width,
        image.height,
        len(texture_data),
    )
    return header + texture_header + texture_data


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Convert a PNG into Ghostship native RGBA16 OTEX resource."
    )
    parser.add_argument("--input", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--width", required=True, type=int)
    parser.add_argument("--height", required=True, type=int)
    args = parser.parse_args()

    with Image.open(args.input) as source:
        source.load()
        if source.size != (args.width, args.height):
            raise ValueError(
                f"{args.input} must be {args.width}x{args.height}; "
                f"got {source.width}x{source.height}"
            )
        resource = build_otex(source)

    expected_size = RESOURCE_HEADER_SIZE + 16 + args.width * args.height * 2
    if len(resource) != expected_size:
        raise RuntimeError(
            f"Generated resource is {len(resource)} bytes; expected {expected_size}"
        )

    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_bytes(resource)


if __name__ == "__main__":
    main()
