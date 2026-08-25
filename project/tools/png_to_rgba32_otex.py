#!/usr/bin/env python3

import argparse
import struct
from pathlib import Path

from PIL import Image


RESOURCE_TYPE_TEXTURE = 0x4F544558
TEXTURE_TYPE_RGBA32 = 1
RESOURCE_HEADER_SIZE = 0x40


def build_otex(image: Image.Image) -> bytes:
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
        TEXTURE_TYPE_RGBA32,
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
    args = parser.parse_args()

    with Image.open(args.input) as source:
        source.load()
        if source.size != (args.width, args.height):
            raise ValueError(
                f"{args.input} must be {args.width}x{args.height}; "
                f"got {source.width}x{source.height}"
            )
        resource = build_otex(source)

    expected_size = RESOURCE_HEADER_SIZE + 16 + args.width * args.height * 4
    if len(resource) != expected_size:
        raise RuntimeError(
            f"Generated resource is {len(resource)} bytes; expected {expected_size}"
        )

    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_bytes(resource)


if __name__ == "__main__":
    main()
