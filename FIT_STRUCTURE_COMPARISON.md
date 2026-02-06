# FIT File Structure Comparison

## Date: January 29, 2026

---

## GARMIN FIT SDK SPECIFICATION (Version 21.141)

### Required Structure for Activity Files:

#### 1. FIT Header (14 bytes with CRC)
- **Byte 0**: Header size (14 = with CRC, 12 = without)
- **Byte 1**: Protocol version (0x20 = protocol 2.0)
- **Bytes 2-3**: Profile version (little-endian uint16, e.g., 0x0839 = 21.05)
- **Bytes 4-7**: Data size (little-endian uint32, excludes header and file CRC)
- **Bytes 8-11**: '.FIT' magic string (ASCII)
- **Bytes 12-13**: Header CRC (CRC-16/CCITT over bytes 0-11)

#### 2. file_id Message (Message Type 0) - REQUIRED
**Required Fields:**
- **Field 0 (type)**: enum - file type (4 = activity)
- **Field 1 (manufacturer)**: uint16 - manufacturer ID
- **Field 2 (product)**: uint16 - product ID
- **Field 3 (serial_number)**: uint32z - device serial (optional)
- **Field 4 (time_created)**: timestamp - creation time (optional but recommended)

#### 3. record Message (Message Type 20) - At Least One Required
**Required Fields:**
- **Field 253 (timestamp)**: timestamp - REQUIRED

**Optional Fields:**
- **Field 0 (position_lat)**: sint32 - latitude in semicircles
- **Field 1 (position_long)**: sint32 - longitude in semicircles
- **Field 5 (distance)**: uint32 - distance in 1/100 meters
- **Field 6 (speed)**: uint16 - speed in 1/1000 m/s
- **Field 7 (power)**: uint16 - power in watts
- **Field 3 (heart_rate)**: uint8 - heart rate in bpm
- **Field 4 (cadence)**: uint8 - cadence in rpm

#### 4. session Message (Message Type 18) - REQUIRED for Activities
**Required Fields:**
- **Field 253 (timestamp)**: timestamp - session end time - REQUIRED
- **Field 2 (start_time)**: timestamp - session start time - REQUIRED
- **Field 7 (total_elapsed_time)**: uint32 - in milliseconds (1/1000 s) - REQUIRED
- **Field 8 (total_timer_time)**: uint32 - in milliseconds (1/1000 s) - REQUIRED
- **Field 5 (sport)**: enum - sport type (2 = cycling) - REQUIRED
- **Field 0 (event)**: enum - event type (8 = session)
- **Field 1 (event_type)**: enum - event type (1 = stop)

#### 5. activity Message (Message Type 34) - REQUIRED for Activities
**Required Fields:**
- **Field 253 (timestamp)**: timestamp - activity end time - REQUIRED
- **Field 1 (total_timer_time)**: uint32 - in milliseconds (1/1000 s)
- **Field 2 (num_sessions)**: uint16 - number of sessions
- **Field 5 (type)**: enum - activity type (0 = manual)

#### 6. File CRC (2 bytes)
- **CRC-16/CCITT** computed over all bytes from offset 0 to end (excluding these 2 CRC bytes)
- **Polynomial**: 0x1021
- **Initial value**: 0x0000

---

## GENERATED FILE STRUCTURE (minimal_test.fit)

### File Size: 180 bytes

### Validation Results:
✅ **Header CRC**: 0x053E (matches computed)
✅ **Data Size**: 164 bytes
✅ **File CRC**: 0xC929 (matches computed)
✅ **Size Formula**: 14 + 164 + 2 = 180 bytes ✓

### Message Breakdown:

#### Header (14 bytes, offset 0-13)
```
0e 20 39 08 a4 00 00 00 2e 46 49 54 3e 05
│  │  │  │  └─────┬─────┘  └───┬───┘  └─┬─┘
│  │  └──┴─ Profile 2105     Magic    CRC
│  └─ Protocol 0x20         ".FIT"    0x053E
└─ Size 14
```

#### Message 1 (offset 14-35): file_id Definition - 22 bytes
- Local type: 0
- Global message: 0 (file_id)
- 5 fields defined:
  1. Field 0 (type): enum, 1 byte
  2. Field 1 (manufacturer): uint16, 2 bytes
  3. Field 2 (product): uint16, 2 bytes
  4. Field 3 (serial_number): uint32z, 4 bytes
  5. Field 4 (time_created): uint32, 4 bytes

#### Message 2 (offset 36-49): file_id Data - 14 bytes
- type = 4 (activity)
- manufacturer = 1 (Garmin)
- product = 0
- serial_number = 0
- time_created = 1138478100 (2026-01-29T22:16:20Z)

#### Message 3 (offset 50-65): record Definition - 16 bytes
- Local type: 1
- Global message: 20 (record)
- 3 fields defined:
  1. Field 253 (timestamp): uint32, 4 bytes
  2. Field 5 (distance): uint32, 4 bytes
  3. Field 6 (speed): uint16, 2 bytes

#### Messages 4-6 (offsets 66-76, 77-87, 88-98): record Data - 11 bytes each
**Record 1** (time +0s):
- timestamp = 1138478100
- distance = 0 cm (0 m)
- speed = 3330 (3.33 m/s = 12 km/h)

**Record 2** (time +3s):
- timestamp = 1138478103
- distance = 1000 cm (10 m)
- speed = 3330 (12 km/h)

**Record 3** (time +6s):
- timestamp = 1138478106
- distance = 2000 cm (20 m)
- speed = 3330 (12 km/h)

#### Message 7 (offset 99-126): session Definition - 28 bytes
- Local type: 2
- Global message: 18 (session)
- 7 fields defined:
  1. Field 0 (event): enum, 1 byte
  2. Field 1 (event_type): enum, 1 byte
  3. Field 253 (timestamp): uint32, 4 bytes
  4. Field 2 (start_time): uint32, 4 bytes
  5. Field 7 (total_elapsed_time): uint32, 4 bytes
  6. Field 8 (total_timer_time): uint32, 4 bytes
  7. Field 5 (sport): enum, 1 byte

#### Message 8 (offset 127-146): session Data - 20 bytes
- event = 8 (session)
- event_type = 1 (stop)
- timestamp = 1138478110 (end time)
- start_time = 1138478100
- total_elapsed_time = 10000 ms (10 seconds)
- total_timer_time = 10000 ms (10 seconds)
- sport = 2 (cycling)

#### Message 9 (offset 147-165): activity Definition - 19 bytes
- Local type: 3
- Global message: 34 (activity)
- 4 fields defined:
  1. Field 253 (timestamp): uint32, 4 bytes
  2. Field 1 (total_timer_time): uint32, 4 bytes
  3. Field 2 (num_sessions): uint16, 2 bytes
  4. Field 5 (type): enum, 1 byte

#### Message 10 (offset 166-177): activity Data - 12 bytes
- timestamp = 1138478110 (2026-01-29T22:16:30Z)
- total_timer_time = 10000 ms (10 seconds)
- num_sessions = 1
- type = 0 (manual)

#### File CRC (offset 178-179): 2 bytes
- Value: 0xC929
- Computed over bytes 0-177

---

## STRUCTURE COMPLIANCE CHECKLIST

| Requirement | Garmin SDK | Generated File | Status |
|------------|------------|----------------|--------|
| Header with CRC | 14 bytes | 14 bytes | ✅ |
| Protocol version | 2.0 (0x20) | 2.0 (0x20) | ✅ |
| Profile version | Any | 21.05 (0x0839) | ✅ |
| Magic string | ".FIT" | ".FIT" | ✅ |
| Header CRC valid | Yes | Yes (0x053E) | ✅ |
| file_id message | Required | Present (msg 0) | ✅ |
| - type field | Required | 4 (activity) | ✅ |
| - manufacturer | Required | 1 (Garmin) | ✅ |
| - product | Required | 0 | ✅ |
| record message | ≥1 required | 3 present (msg 20) | ✅ |
| - timestamp field | Required | Present | ✅ |
| session message | Required | Present (msg 18) | ✅ |
| - timestamp | Required | Present | ✅ |
| - start_time | Required | Present | ✅ |
| - total_elapsed_time | Required | 10000 ms | ✅ |
| - total_timer_time | Required | 10000 ms | ✅ |
| - sport | Required | 2 (cycling) | ✅ |
| - event | Required | 8 (session) | ✅ |
| - event_type | Required | 1 (stop) | ✅ |
| activity message | Required | Present (msg 34) | ✅ |
| - timestamp | Required | Present | ✅ |
| - total_timer_time | Optional | 10000 ms | ✅ |
| - num_sessions | Optional | 1 | ✅ |
| - type | Optional | 0 (manual) | ✅ |
| File CRC | 2 bytes | 2 bytes (0xC929) | ✅ |
| File CRC valid | Yes | Yes | ✅ |
| Size formula | 14+data+2 | 14+164+2=180 | ✅ |

---

## KEY FINDINGS

1. **Complete Compliance**: Our generated file meets 100% of Garmin FIT SDK requirements for activity files
2. **Minimal Structure**: Uses only required messages and fields for maximum compatibility
3. **CRC Validation**: Both header and file CRCs compute correctly using CRC-16/CCITT
4. **Message Ordering**: Follows standard order: file_id → records → session → activity
5. **Field Requirements**: All REQUIRED fields present in session and activity messages

---

## NEXT STEPS

1. **Upload Test**: Upload `minimal_test.fit` to Strava to validate acceptance
2. **App Integration**: If Strava accepts, restart app with updated code and test
3. **Field Enhancement**: Add optional fields (GPS, heart rate, cadence) after basic structure validated
4. **Developer Fields**: Add custom developer fields after core structure confirmed working

---

Generated: January 29, 2026
Validation Tool: `validate_fit.py`
Generation Tool: `generate_minimal_fit.py`
