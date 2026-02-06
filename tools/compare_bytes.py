#!/usr/bin/env python3
# Compare file structures
our = open(r'..\test_data\coast_down_20260129_225448.fit', 'rb').read()
wahoo = open(r'..\test_data\export_57540117\activities\9859815826.fit\9859815826.fit', 'rb').read()

print('OUR FILE (first 100 bytes):')
for i in range(0, min(100, len(our)), 20):
    print(f'{i:3d}: {" ".join(f"{b:02x}" for b in our[i:i+20])}')

print('\nWAHOO FILE (first 100 bytes):')
for i in range(0, min(100, len(wahoo)), 20):
    print(f'{i:3d}: {" ".join(f"{b:02x}" for b in wahoo[i:i+20])}')

print(f'\nOUR header: {" ".join(f"{b:02x}" for b in our[:14])}')
print(f'WAHOO header: {" ".join(f"{b:02x}" for b in wahoo[:14])}')

# Check profile version
our_profile = our[2] | (our[3] << 8)
wahoo_profile = wahoo[2] | (wahoo[3] << 8)
print(f'\nOUR profile version: {our_profile} (0x{our_profile:04x})')
print(f'WAHOO profile version: {wahoo_profile} (0x{wahoo_profile:04x})')
