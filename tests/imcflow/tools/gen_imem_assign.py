#!/usr/bin/env python3
"""
gen_imem_assign.py

Read a binary file or an xxd -i generated C array file and emit lines like
  inode_slv_imem[i] = 0xXXXXXXXX;

Usage examples:
  python3 gen_imem_assign.py --file your.imem.bin --var inode_slv_imem --base 0 --endian le > imem_assign.c.inc
  xxd -i your.imem.bin > your_imem_bytes.c
  python3 gen_imem_assign.py --file your_imem_bytes.c --var inode_slv_imem --endian le > imem_assign.c.inc

Options:
  --file/-f <path>   Input .bin or xxd -i .c file (required)
  --var <name>       Target array variable name (default: inode_slv_imem)
  --base <index>     Starting index offset (default: 0)
  --endian <le|be>   Byte order when packing 4 bytes into a word (default: le)

Notes:
  - If the input is xxd -i output, hex tokens like 0xNN are parsed.
  - If byte count is not multiple of 4, trailing zeros are padded.
"""

from __future__ import annotations

import argparse
import io
import os
import re
import sys
from typing import List


def parse_args(argv: List[str]) -> argparse.Namespace:
  p = argparse.ArgumentParser(add_help=True)
  p.add_argument("--file", "-f", required=True, help="Input .bin or xxd -i C file")
  p.add_argument("--var", default="inode_slv_imem", help="Target array variable name")
  p.add_argument("--base", type=int, default=0, help="Starting index offset")
  p.add_argument("--endian", choices=["le", "be"], default="le", help="Word packing endianness")
  return p.parse_args(argv)


HEX_TOKEN_RE = re.compile(r"0[xX]([0-9a-fA-F]+)")


def read_text_hex_tokens(path: str) -> List[int] | None:
  """Parse 0xNN tokens from a text file. Return list of byte values (0..255), or None if no tokens found."""
  try:
    with open(path, "r", encoding="utf-8", errors="ignore") as f:
      s = f.read()
  except OSError:
    return None

  if "0x" not in s and "0X" not in s:
    return None

  bytes_out: List[int] = []
  for m in HEX_TOKEN_RE.finditer(s):
    hex_str = m.group(1)
    # Convert token to integer
    try:
      val = int(hex_str, 16)
    except ValueError:
      continue
    if val <= 0xFF:
      bytes_out.append(val)
    else:
      # Wider token: split into bytes big-endian order from token
      be_bytes: List[int] = []
      v = val
      if v == 0:
        be_bytes = [0]
      else:
        tmp: List[int] = []
        while v > 0:
          tmp.append(v & 0xFF)
          v >>= 8
        be_bytes = list(reversed(tmp))
      bytes_out.extend(be_bytes)

  return bytes_out


def read_binary(path: str) -> List[int]:
  with open(path, "rb") as f:
    return list(f.read())


def pack_words(bytes_in: List[int], endian: str) -> List[int]:
  out: List[int] = []
  # pad to 4-byte boundary
  while len(bytes_in) % 4 != 0:
    bytes_in.append(0)
  for i in range(0, len(bytes_in), 4):
    b0, b1, b2, b3 = bytes_in[i : i + 4]
    if endian == "le":
      word = (b0 << 0) | (b1 << 8) | (b2 << 16) | (b3 << 24)
    else:
      word = (b0 << 24) | (b1 << 16) | (b2 << 8) | (b3 << 0)
    out.append(word & 0xFFFFFFFF)
  return out


def main(argv: List[str]) -> int:
  args = parse_args(argv)

  # Try to parse as xxd -i style text first
  bytes_in = read_text_hex_tokens(args.file)
  if bytes_in is None:
    # Fallback to raw binary
    try:
      bytes_in = read_binary(args.file)
    except OSError as e:
      print(f"error: failed to read input: {e}", file=sys.stderr)
      return 1

  words = pack_words(bytes_in, args.endian)
  base = int(args.base)
  var = args.var

  out = io.StringIO()
  for idx, w in enumerate(words):
    out.write(f"{var}[{base + idx}] = 0x{w:08x};\n")

  sys.stdout.write(out.getvalue())
  return 0


if __name__ == "__main__":
  raise SystemExit(main(sys.argv[1:]))
