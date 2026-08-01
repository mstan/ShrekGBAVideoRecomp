#!/usr/bin/env python3
"""Drive Play on native + mGBA TCP peers and locate the first pixel/state split."""

from __future__ import annotations

import argparse
import json
import pathlib
import socket
import time


class Client:
    def __init__(self, port: int):
        deadline = time.time() + 10
        self.sock = None
        while time.time() < deadline:
            try:
                self.sock = socket.create_connection(("127.0.0.1", port), 2)
                break
            except OSError:
                time.sleep(0.1)
        if self.sock is None:
            raise RuntimeError(f"could not connect to TCP port {port}")
        self.buf = b""

    def call(self, **request) -> dict:
        self.sock.sendall(json.dumps(request).encode() + b"\n")
        while b"\n" not in self.buf:
            data = self.sock.recv(1 << 20)
            if not data:
                raise RuntimeError("TCP peer closed")
            self.buf += data
        line, _, self.buf = self.buf.partition(b"\n")
        return json.loads(line)

    def read_region(self, command: str, size: int) -> bytes:
        result = bytearray()
        for offset in range(0, size, 4096):
            count = min(4096, size - offset)
            response = self.call(cmd=command, addr=offset, len=count)
            result += bytes.fromhex(response["data"])
        return bytes(result)


def first_diff(a: bytes, b: bytes) -> int | None:
    for index, (av, bv) in enumerate(zip(a, b)):
        if av != bv:
            return index
    return None if len(a) == len(b) else min(len(a), len(b))


def step_to(client: Client, command: str, target: int) -> int:
    frame = int(client.call(cmd="frame")["frame"])
    while frame < target:
        frame = int(client.call(cmd=command)["frame"])
    return frame


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--native-port", type=int, default=19883)
    parser.add_argument("--oracle-port", type=int, default=19843)
    parser.add_argument("--menu-frame", type=int, default=1200)
    parser.add_argument("--scan", type=int, default=200)
    args = parser.parse_args()

    native = Client(args.native_port)
    oracle = Client(args.oracle_port)
    step_to(native, "step", args.menu_frame)
    step_to(oracle, "emu_step", args.menu_frame)

    native.call(cmd="set_keyinput", value=0x03FE)
    oracle.call(cmd="emu_set_keys", keys=1)
    for _ in range(3):
        native.call(cmd="step")
        oracle.call(cmd="emu_step")
    native.call(cmd="set_keyinput", value=0x03FF)
    oracle.call(cmd="emu_set_keys", keys=0)

    native_frame = int(native.call(cmd="frame")["frame"])
    oracle_frame = int(oracle.call(cmd="frame")["frame"])
    while native_frame != oracle_frame:
        target = max(native_frame, oracle_frame)
        if native_frame < target:
            native_frame = step_to(native, "step", target)
        if oracle_frame < target:
            oracle_frame = step_to(oracle, "emu_step", target)
    target = native_frame
    print(f"aligned after Play at frame {target}", flush=True)

    for relative in range(args.scan + 1):
        native_ewram = native.read_region("read_ewram", 0x40000)
        oracle_ewram = oracle.read_region("read_emu_ewram", 0x40000)
        ewram_diff = first_diff(native_ewram, oracle_ewram)
        native_pixels = bytes.fromhex(native.call(cmd="screenshot")["data"])
        oracle_pixels = bytes.fromhex(
            oracle.call(cmd="emu_screenshot")["data"])
        pixel_diff = first_diff(native_pixels, oracle_pixels)
        if ewram_diff is not None or pixel_diff is not None:
            if ewram_diff is not None:
                print(
                    f"FIRST EWRAM DIVERGENCE relative={relative} frame={target} "
                    f"offset=0x{ewram_diff:x} "
                    f"native={native_ewram[ewram_diff]:02x} "
                    f"oracle={oracle_ewram[ewram_diff]:02x}",
                    flush=True)
            if pixel_diff is None:
                print("  framebuffer still identical", flush=True)
            else:
                pixel = pixel_diff // 3
                print(
                    f"FIRST PIXEL DIVERGENCE relative={relative} frame={target} "
                    f"x={pixel % 240} y={pixel // 240} "
                    f"channel={pixel_diff % 3} "
                    f"native={native_pixels[pixel_diff]:02x} "
                    f"oracle={oracle_pixels[pixel_diff]:02x}",
                    flush=True)
            for name, ncmd, ocmd, size in (
                ("IWRAM", "read_iwram", "read_emu_iwram", 0x8000),
                ("VRAM", "read_vram", "read_emu_vram", 0x18000),
            ):
                nblob = native.read_region(ncmd, size)
                oblob = oracle.read_region(ocmd, size)
                offset = first_diff(nblob, oblob)
                if offset is None:
                    print(f"  {name}: identical")
                else:
                    print(
                        f"  {name}: first diff +0x{offset:x} "
                        f"native={nblob[offset]:02x} oracle={oblob[offset]:02x}")
            return 1
        if relative and relative % 25 == 0:
            print(f"  frame {target}: pixels identical", flush=True)
        if relative == args.scan:
            break
        native_frame = int(native.call(cmd="step")["frame"])
        oracle_frame = int(oracle.call(cmd="emu_step")["frame"])
        while native_frame != oracle_frame:
            target = max(native_frame, oracle_frame)
            if native_frame < target:
                native_frame = step_to(native, "step", target)
            if oracle_frame < target:
                oracle_frame = step_to(oracle, "emu_step", target)
        target = native_frame

    print(f"pixels identical for {args.scan} post-Play frames")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
