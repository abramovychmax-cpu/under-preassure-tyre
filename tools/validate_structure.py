#!/usr/bin/env python3
"""Validate FIT file structure."""
path = r'd:\TYRE PREASSURE APP\tyre_preassure\test_data\coast_down_20260129_202618.fit'
with open(path, 'rb') as f:
    data = f.read()

data_size = int.from_bytes(data[4:8], 'little')
print(f"Total file: {len(data)} bytes")
print(f"Data size from header (bytes 4-7): {data_size} bytes")
print(f"Expected: 14 (header) + {data_size} (data) + 2 (CRC) = {14 + data_size + 2}")
print(f"Match: {len(data) == 14 + data_size + 2}")
print()

# Show last messages
print("Last 50 bytes of file:")
for i in range(len(data) - 50, len(data), 10):
    chunk = data[i:i+10]
    hex_str = ' '.join(f'{b:02x}' for b in chunk)
    print(f"  {i:3d}: {hex_str}")
