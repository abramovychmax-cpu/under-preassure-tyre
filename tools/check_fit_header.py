#!/usr/bin/env python3
"""
Quick FIT header validator.

Usage:
    python check_fit_header.py path/to/file.fit

This prints the FIT header fields and a short hex preview of the file.
"""
import sys
import os
import struct


def read_header(path):
    with open(path, 'rb') as f:
        data = f.read(64)
    if len(data) < 12:
        print('File too small to be a FIT file')
        return

    # header_size: uint8
    header_size = data[0]
    protocol_ver = data[1]
    profile_ver = struct.unpack_from('<H', data, 2)[0]
    data_size = struct.unpack_from('<I', data, 4)[0]
    data_type = data[8:12].decode('ascii', errors='replace')

    print('Header size:', header_size)
    print('Protocol version (raw):', protocol_ver)
    print('Profile version:', profile_ver)
    print('Data size from header:', data_size)
    print('Data type string:', repr(data_type))

    if data_type == '.FIT':
        print('Looks like a valid FIT header (data_type .FIT)')
    else:
        print('Warning: data_type is not .FIT — file may be different or corrupted')

    print('\nFirst 64 bytes (hex):')
    print(' '.join(f"{b:02x}" for b in data))


def main():
    if len(sys.argv) < 2:
        print('Usage: check_fit_header.py file.fit')
        sys.exit(1)
    path = sys.argv[1]
    if not os.path.isfile(path):
        print('File not found:', path)
        sys.exit(1)
    read_header(path)


if __name__ == '__main__':
    main()
