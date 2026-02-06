#!/usr/bin/env python3
import struct
import os
import sys

# Try to find the uncompressed FIT file
strava_file = "test_data/export_57540117/activities/8422253208.fit"
strava_dir = "test_data/export_57540117/activities/8422253208.fit"

# Check if it's a directory
if os.path.isdir(strava_dir):
    print(f"{strava_dir} is a directory, listing contents:")
    for f in os.listdir(strava_dir):
        print(f"  {f}")
else:
    # Try to read it as a file
    try:
        with open(strava_file, 'rb') as f:
            data = f.read()
        print(f"Successfully read {len(data)} bytes from {strava_file}")
    except Exception as e:
        print(f"Error reading file: {e}")

# Look for other FIT files in test_data
print("\nSearching for FIT files in test_data:")
for root, dirs, files in os.walk("test_data"):
    for f in files:
        if f.endswith(".fit") and not f.endswith(".fit.gz"):
            filepath = os.path.join(root, f)
            size = os.path.getsize(filepath)
            print(f"  {filepath} ({size} bytes)")

print("\nSearching for FIT files in entire project:")
for root, dirs, files in os.walk("."):
    # Skip hidden directories and node_modules type folders
    dirs[:] = [d for d in dirs if not d.startswith('.') and d not in ['build', '.git']]
    for f in files:
        if f.endswith(".fit") and not f.endswith(".fit.gz"):
            filepath = os.path.join(root, f)
            size = os.path.getsize(filepath)
            print(f"  {filepath} ({size} bytes)")
