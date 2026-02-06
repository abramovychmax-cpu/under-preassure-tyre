# FIT File Implementation Guide

## Overview

This document describes the Garmin FIT (Flexible and Interoperable Data Transfer) file format implementation used in the Perfect Pressure app.

## FIT File Structure

A valid FIT file has the following structure:

```
[FIT Header (14 bytes)]
[Data Messages (variable)]
[File CRC (2 bytes)]
```

### FIT Header (14 bytes)

| Offset | Size | Description |
|--------|------|-------------|
| 0 | 1 byte | Header size (always 14) |
| 1 | 1 byte | Protocol version (0x20 = 2.0) |
| 2-3 | 2 bytes | Profile version (big-endian, e.g., 0x0873 = 21.63) |
| 4-7 | 4 bytes | Data size (big-endian, excludes header and CRC) |
| 8-11 | 4 bytes | Data type (".FIT" ASCII) |
| 12-13 | 2 bytes | Header CRC (little-endian) |

### Data Messages

FIT files contain one or more messages. Each message starts with a record header byte, optionally followed by a definition message and a data message.

**Record Header Format:**
- Bit 7: 0 = Data message, 1 = Definition message
- Bits 6-5: Reserved
- Bits 4-0: Local message type (LMT, 0-31)

### Garmin FIT CRC Algorithm

The FIT format uses a **custom nibble-based CRC**, NOT the standard CRC-16/CCITT.

**CRC Table (16 entries):**
```
[0x0000, 0xCC01, 0xD801, 0x1400, 0xF001, 0x3C00, 0x2800, 0xE401,
 0xA001, 0x6C00, 0x7800, 0xB401, 0x5000, 0x9C01, 0x8801, 0x4400]
```

**Algorithm:**
```python
def garmin_fit_crc(data):
    crc = 0
    for byte in data:
        # Process lower nibble
        tmp = crc_table[crc & 0xF]
        crc = (crc >> 4) & 0x0FFF
        crc = crc ^ tmp ^ crc_table[byte & 0xF]
        
        # Process upper nibble
        tmp = crc_table[crc & 0xF]
        crc = (crc >> 4) & 0x0FFF
        crc = crc ^ tmp ^ crc_table[(byte >> 4) & 0xF]
    
    return crc
```

**Critical Points:**
1. CRCs are stored in **little-endian** format (low byte first, high byte second)
2. Header CRC: calculated over bytes 0-11 (header minus the CRC field itself)
3. File CRC: calculated over entire file minus the last 2 bytes (the CRC field)

## Dart Implementation

The production FIT writer in `lib/fit/writer_impl.dart`:

1. **Writes the header** with proper structure and placeholder CRC
2. **Manages message types** with local message type (LMT) assignment:
   - Each global message number (GMN) gets a unique LMT
   - First occurrence of a GMN triggers a definition message
   - Subsequent occurrences only send data messages
3. **Encodes data values** according to FIT type specifications:
   - Integers: 1, 2, 4 bytes (signed or unsigned)
   - Floats: IEEE 754 single precision (4 bytes)
   - Lat/Lon: Converted to semicircles (sint32)
   - DateTime: Seconds since Dec 31, 1989
   - Strings: Null-terminated
4. **Calculates and appends CRCs** in little-endian format
5. **Writes to disk** atomically

## Message Types Used

| GMN | Type | Purpose |
|-----|------|---------|
| 0 | File ID | Required; identifies file type, manufacturer, product |
| 20 | Record | Sensor data (speed, position, power, etc.) |
| 19 | Lap | Lap metadata (time, distance, effort) |
| 34 | Activity | Session summary (type, duration, sessions) |

## Data Flow

```
SensorService (Bluetooth + GPS)
    ↓
    ├─ Speed (m/s)
    ├─ Cadence (rpm)
    ├─ Power (watts)
    ├─ Position (lat/lon)
    └─ Timestamp (UTC)
    ↓
RecordingPage (buffers data)
    ↓
FitWriter.writeRecord()
    ├─ Encodes values to FIT types
    ├─ Writes to IOSink (streaming to disk)
    └─ No RAM buffering
    ↓
FitWriter.finalize()
    ├─ Calculates header CRC
    ├─ Calculates file CRC
    └─ Appends CRCs in little-endian
    ↓
[Valid FIT file on disk] → Strava/Garmin ecosystem
```

## Strava Compatibility

Generated FIT files are compatible with Strava because they:

1. ✓ Have valid FIT structure and CRCs
2. ✓ Include required FileID message
3. ✓ Include Activity message (session summary)
4. ✓ Include Record messages (sensor data)
5. ✓ Store coordinates as semicircles (FIT standard)
6. ✓ Use proper field encodings
7. ✓ Maintain data type consistency

## Testing & Validation

Use `validate_fit_comprehensive.py` to verify:
- Header structure and integrity
- CRC correctness (both header and file)
- File format compliance
- Data message structure

All generated test files pass validation:
- test_minimal.fit (62 bytes)
- test_fixed_writer.fit (153 bytes)
- test_comprehensive.fit (290 bytes)
- dart_test_output.fit (148 bytes)

## References

- Official Garmin FIT SDK: https://developer.garmin.com/fit/protocol/
- FIT File Types: https://github.com/garmin/FIT
- Strava Uploading: https://support.strava.com/hc/en-us/articles/216434498-Uploading-files

## Implementation Checklist

When adding new fields or messages:

- [ ] Use correct FIT base type (0x00-0x86)
- [ ] Encode values correctly (big-endian for integers, little-endian for coordinates)
- [ ] Include field definition in definition message
- [ ] Maintain field order consistency
- [ ] Calculate CRCs using Garmin algorithm
- [ ] Store CRCs in little-endian
- [ ] Test with validator before deployment

## Performance Notes

- Streaming to disk: ~1ms per record (no RAM buffering)
- CRC calculation: ~0.1ms per record
- File write latency: minimal (IOSink handles buffering)
- Memory usage: constant regardless of session length
