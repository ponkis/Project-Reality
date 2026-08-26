#!/usr/bin/env python3

import argparse
import struct
from pathlib import Path

from PIL import Image


RESOURCE_TYPE_TEXTURE = 0x4F544558
TEXTURE_TYPE_RGBA32 = 1
TEXTURE_TYPE_RGBA16 = 2
RESOURCE_HEADER_SIZE = 0x40


def encode_rgba16(image: Image.Image) -> bytes:
    texture_data = bytearray()

    for red, green, blue, alpha in image.convert("RGBA").getdata():
        pixel = ((red >> 3) << 11) | ((green >> 3) << 6) | ((blue >> 3) << 1)
        pixel |= 1 if alpha != 0 else 0
        texture_data.extend(pixel.to_bytes(2, byteorder="big"))

    return bytes(texture_data)


def build_otex(image: Image.Image, texture_format: str) -> bytes:
    if texture_format == "rgba16":
        texture_type = TEXTURE_TYPE_RGBA16
        texture_data = encode_rgba16(image)
    else:
        texture_type = TEXTURE_TYPE_RGBA32
        texture_data = image.convert("RGBA").tobytes()
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
        texture_type,
        image.width,
        image.height,
        len(texture_data),
    )
    return header + texture_header + texture_data


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Convert a PNG into a Ghostship native RGBA32 OTEX resource."
    )
    parser.add_argument("--input", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--width", required=True, type=int)
    parser.add_argument("--height", required=True, type=int)
    parser.add_argument(
        "--format",
        choices=("rgba16", "rgba32"),
        default="rgba32",
        help="Native texture format (default: rgba32)",
    )
    args = parser.parse_args()

    with Image.open(args.input) as source:
        source.load()
        if source.size != (args.width, args.height):
            raise ValueError(
                f"{args.input} must be {args.width}x{args.height}; "
                f"got {source.width}x{source.height}"
            )
        resource = build_otex(source, args.format)

    bytes_per_pixel = 2 if args.format == "rgba16" else 4
    expected_size = RESOURCE_HEADER_SIZE + 16 + args.width * args.height * bytes_per_pixel
    if len(resource) != expected_size:
        raise RuntimeError(
            f"Generated resource is {len(resource)} bytes; expected {expected_size}"
        )

    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_bytes(resource)


if __name__ == "__main__":
    main()
