#!/usr/bin/env python3
"""
Inspect FIT file structure - show all available fields in records.
"""

from fitparse import FitFile
from collections import defaultdict

fit = FitFile('test_data/10255893432.fit')

# Collect all unique field names across all records
field_names = set()
record_fields = defaultdict(set)

for message in fit.messages:
    msg_name = message.name
    for field in message.fields:
        field_name = field.name
        field_names.add(field_name)
        record_fields[msg_name].add(field_name)

print("=" * 80)
print("FIT FILE STRUCTURE: test_data/10255893432.fit")
print("=" * 80)

print("\nAll Message Types in file:")
for msg_type in sorted(record_fields.keys()):
    field_count = len(record_fields[msg_type])
    print(f"  {msg_type:20} - {field_count:2} fields")

print("\n" + "=" * 80)
print("RECORD MESSAGE FIELDS (sensor data):")
print("=" * 80)

if 'record' in record_fields:
    for field_name in sorted(record_fields['record']):
        print(f"  - {field_name}")

print("\n" + "=" * 80)
print("LAP MESSAGE FIELDS (lap metadata):")
print("=" * 80)

if 'lap' in record_fields:
    for field_name in sorted(record_fields['lap']):
        print(f"  - {field_name}")

print("\n" + "=" * 80)
print("FILE_ID MESSAGE FIELDS:")
print("=" * 80)

if 'file_id' in record_fields:
    for field_name in sorted(record_fields['file_id']):
        print(f"  - {field_name}")

# Show sample record data
print("\n" + "=" * 80)
print("SAMPLE RECORD (first sensor record):")
print("=" * 80)

for message in fit.messages:
    if message.name == 'record':
        for field in message.fields:
            value = field.value
            print(f"  {field.name:25} = {value}")
        break
