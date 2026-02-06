#!/usr/bin/env python3
"""
Proper FIT file generation for Strava compatibility.
Using standard FIT message types and field definitions.
"""

import struct
import json
import math
import random
from datetime import datetime
from pathlib import Path

# FIT Protocol constants
FIT_HEADER_SIZE = 14
FIT_PROTOCOL_VERSION = 0x20
FIT_PROFILE_VERSION = 2314

# Message types
MSG_FILE_ID = 0
MSG_RECORD = 20
MSG_EVENT = 21
MSG_DEVICE_INFO = 23
MSG_ACTIVITY = 34
MSG_SESSION = 18
MSG_LAP = 19

# File types
FILE_TYPE_ACTIVITY = 4

# Physics constants
GRAVITY = 9.81
TOTAL_MASS = 90
AIR_DENSITY = 1.225
CD = 1.1
FRONTAL_AREA = 0.5

# Agricola Street
STREET_LENGTH = 500.0
ELEVATION_DROP = 25.0
STREET_GRADIENT = ELEVATION_DROP / STREET_LENGTH
STREET_ANGLE = math.atan(STREET_GRADIENT)


class PhysicsSimulator:
    """Realistic cycling physics."""
    
    def __init__(self, tire_pressure_bar):
        self.pressure = tire_pressure_bar
        self.mass = TOTAL_MASS
        self.crr = max(0.003, 0.008 - 0.0006 * (tire_pressure_bar - 3.0))
    
    def _rolling_resistance(self, speed_ms):
        normal_force = self.mass * GRAVITY * math.cos(STREET_ANGLE)
        return self.crr * normal_force
    
    def _air_drag(self, speed_ms):
        return 0.5 * AIR_DENSITY * CD * FRONTAL_AREA * (speed_ms ** 2)
    
    def _gravity_component(self):
        return self.mass * GRAVITY * math.sin(STREET_ANGLE)
    
    def simulate_descent(self, duration_seconds=40):
        data = []
        speed = 0.0
        position = 0.0
        dt = 0.1
        
        for step in range(int(duration_seconds / dt)):
            time = step * dt
            
            gravity_force = self._gravity_component()
            rolling_force = self._rolling_resistance(speed)
            drag_force = self._air_drag(speed)
            
            brake_position = STREET_LENGTH * 0.8
            if position >= brake_position:
                brake_intensity = (position - brake_position) / (STREET_LENGTH - brake_position)
                brake_force = 400 * brake_intensity
            else:
                brake_force = 0
            
            net_force = gravity_force - rolling_force - drag_force - brake_force
            acceleration = net_force / self.mass
            speed = max(0, speed + acceleration * dt)
            position = min(STREET_LENGTH, position + speed * dt)
            
            elevation = 100.0 - (position / STREET_LENGTH) * ELEVATION_DROP
            cadence = 0 if speed < 5 else int(30 + (speed - 5) * 2)
            power = int(speed * brake_force)
            
            data.append({
                'time': time,
                'position': position,
                'speed': speed,
                'power': power,
                'elevation': elevation,
                'cadence': min(120, cadence),
            })
            
            if position >= STREET_LENGTH and speed < 1.0:
                break
        
        return data
    
    def simulate_climb(self, duration_seconds=90):
        data = []
        position = STREET_LENGTH
        speed = 2.0
        pedal_power = 300
        dt = 0.1
        
        for step in range(int(duration_seconds / dt)):
            time = step * dt
            
            gravity_force = self._gravity_component()
            rolling_force = self._rolling_resistance(speed)
            drag_force = self._air_drag(speed)
            
            if speed > 0.5:
                pedal_force = pedal_power / speed
            else:
                pedal_force = 200
            
            net_force = pedal_force - gravity_force - rolling_force - drag_force
            acceleration = net_force / self.mass
            speed = max(0.5, speed + acceleration * dt)
            position = max(0, position - speed * dt)
            
            elevation = 100.0 - (position / STREET_LENGTH) * ELEVATION_DROP
            cadence = int(85 + random.gauss(0, 5))
            cadence = max(70, min(110, cadence))
            power = pedal_power + int(random.gauss(0, 10))
            
            data.append({
                'time': time,
                'position': position,
                'speed': speed,
                'power': power,
                'elevation': elevation,
                'cadence': cadence,
            })
            
            if position <= 0:
                break
        
        return data


class FITWriter:
    """Write proper FIT files for Strava."""
    
    def __init__(self, filepath):
        self.filepath = filepath
        self.records = []
        self.base_time = int(datetime.now().timestamp())
    
    def _crc16(self, data):
        """Calculate CRC-16 CCITT."""
        crc = 0
        for byte in data:
            crc = ((crc << 8) ^ byte) & 0xFFFF
            for _ in range(8):
                if crc & 0x8000:
                    crc = ((crc << 1) ^ 0xCC01) & 0xFFFF
                else:
                    crc = (crc << 1) & 0xFFFF
        return crc
    
    def add_file_id(self):
        """File ID message (type 0)."""
        # Field 253: timestamp
        # Field 0: type (4 = activity)
        # Field 1: manufacturer (1 = garmin)
        # Field 2: product (0)
        # Field 3: serial_number
        # Field 4: time_created
        
        data = struct.pack('<BI', 4, 1)  # type + manufacturer
        data += struct.pack('<H', 0)      # product
        data += struct.pack('<I', 12345)  # serial number
        
        self.records.append((MSG_FILE_ID, data))
    
    def add_device_info(self, timestamp):
        """Device info message."""
        data = struct.pack('<I', timestamp)  # timestamp
        data += struct.pack('<H', 0)          # device index
        data += struct.pack('<B', 0)          # battery status
        
        self.records.append((MSG_DEVICE_INFO, data))
    
    def add_record(self, timestamp, lat, lon, altitude, speed, distance, cadence, power):
        """Record message (type 20) - sensor data."""
        data = struct.pack('<I', timestamp)
        
        # Position (lat/lon in semicircles)
        lat_semicircles = int(lat * (2**31) / 180.0)
        lon_semicircles = int(lon * (2**31) / 180.0)
        data += struct.pack('<i', lat_semicircles)
        data += struct.pack('<i', lon_semicircles)
        
        # Altitude (m)
        data += struct.pack('<H', int(altitude * 5) + 500)  # FIT format: (alt*5)+500
        
        # Heart rate (use 0 since we don't have it)
        data += struct.pack('<B', 0xff)
        
        # Cadence (RPM)
        data += struct.pack('<B', int(cadence))
        
        # Speed (m/s * 100)
        data += struct.pack('<H', int(speed * 100))
        
        # Power (watts)
        data += struct.pack('<H', int(power) & 0xFFFF)
        
        # Distance (m * 100)
        data += struct.pack('<I', int(distance * 100))
        
        # Temperature (use 0)
        data += struct.pack('<b', 25)
        
        self.records.append((MSG_RECORD, data))
    
    def add_event(self, timestamp, event_type=0):
        """Event message - marks lap/segment."""
        data = struct.pack('<I', timestamp)
        data += struct.pack('<BB', event_type, 0)  # event type and data
        
        self.records.append((MSG_EVENT, data))
    
    def add_lap(self, timestamp, start_time, total_distance, total_elapsed_time, 
                avg_speed, max_speed, avg_cadence, max_cadence, avg_power, max_power,
                total_descent, num_laps):
        """Lap message (type 19)."""
        data = struct.pack('<I', timestamp)        # timestamp
        data += struct.pack('<I', start_time)       # start_time
        data += struct.pack('<H', 1)                # event (1 = lap)
        data += struct.pack('<B', 0)                # event type
        data += struct.pack('<I', int(total_elapsed_time))  # total_elapsed_time (ms)
        data += struct.pack('<I', int(total_distance))      # total_distance (m*100)
        data += struct.pack('<I', int(avg_speed))           # avg_speed (m/s*100)
        data += struct.pack('<I', int(max_speed))           # max_speed
        data += struct.pack('<B', int(avg_cadence))         # avg_cadence
        data += struct.pack('<B', int(max_cadence))         # max_cadence
        data += struct.pack('<H', int(avg_power) & 0xFFFF)  # avg_power (watts)
        data += struct.pack('<H', int(max_power) & 0xFFFF)  # max_power
        
        self.records.append((MSG_LAP, data))
    
    def add_session(self, timestamp, start_time, total_distance, total_elapsed_time,
                    avg_speed, max_speed, avg_cadence, max_cadence, avg_power, max_power,
                    total_descent, num_laps):
        """Session message (type 18)."""
        data = struct.pack('<I', timestamp)        # timestamp
        data += struct.pack('<I', start_time)       # start_time
        data += struct.pack('<B', 1)                # sport (1=cycling)
        data += struct.pack('<B', 0)                # sub_sport
        data += struct.pack('<I', int(total_elapsed_time))
        data += struct.pack('<I', int(total_distance))
        data += struct.pack('<I', int(avg_speed))
        data += struct.pack('<I', int(max_speed))
        data += struct.pack('<B', int(avg_cadence))
        data += struct.pack('<B', int(max_cadence))
        data += struct.pack('<H', int(avg_power) & 0xFFFF)
        data += struct.pack('<H', int(max_power) & 0xFFFF)
        data += struct.pack('<I', int(total_descent))
        data += struct.pack('<B', int(num_laps))
        
        self.records.append((MSG_SESSION, data))
    
    def write(self):
        """Write FIT file to disk."""
        # Build data buffer
        data_buffer = b''
        
        for msg_type, msg_data in self.records:
            # Message header (normal header = 0x40 + type)
            data_buffer += bytes([0x40, msg_type])
            data_buffer += msg_data
        
        # Calculate CRC
        data_crc = self._crc16(data_buffer)
        
        # Write file
        with open(self.filepath, 'wb') as f:
            # Header
            f.write(bytes([FIT_HEADER_SIZE, FIT_PROTOCOL_VERSION]))
            f.write(struct.pack('<H', FIT_PROFILE_VERSION))
            f.write(struct.pack('<I', len(data_buffer)))
            f.write(b'.FIT')
            
            # Data
            f.write(data_buffer)
            
            # CRC
            f.write(struct.pack('<H', data_crc))


def generate():
    """Generate continuous FIT file with 3 runs."""
    
    start_lat = 52.2420
    start_lon = 21.0455
    end_lat = 52.2395
    end_lon = 21.0470
    
    pressures = [(3.5, 1), (4.4, 2), (5.0, 3)]
    
    output_dir = Path('assets/simulations')
    output_dir.mkdir(parents=True, exist_ok=True)
    fit_path = output_dir / 'agricola_strava.fit'
    
    writer = FITWriter(str(fit_path))
    writer.add_file_id()
    
    base_time = writer.base_time
    global_time = 0
    all_stats = []
    
    print('=' * 70)
    print('Generating Strava-Compatible FIT File')
    print('=' * 70)
    
    for pressure_bar, run_num in pressures:
        print(f'\n✓ Run {run_num}: {pressure_bar} bar')
        
        sim = PhysicsSimulator(pressure_bar)
        descent_data = sim.simulate_descent(60)
        climb_data = sim.simulate_climb(90)
        run_data = descent_data + climb_data
        
        # Add device info at start of run
        writer.add_device_info(base_time + int(global_time))
        
        run_start_time = base_time + int(global_time)
        
        # Collect stats
        all_speeds = []
        all_powers = []
        all_elevations = []
        all_cadences = []
        all_positions = []
        descent_speeds = []
        climb_speeds = []
        climb_powers = []
        
        # Write records
        for idx, point in enumerate(run_data):
            timestamp = int(base_time + global_time + point['time'])
            
            # GPS
            progress = min(1.0, point['position'] / STREET_LENGTH)
            lat = start_lat + (end_lat - start_lat) * progress
            lon = start_lon + (end_lon - start_lon) * progress
            
            elevation = point['elevation']
            speed = point['speed']
            cadence = point['cadence']
            power = point['power']
            
            all_speeds.append(speed)
            all_powers.append(power)
            all_elevations.append(elevation)
            all_cadences.append(cadence)
            all_positions.append(point['position'])
            
            if idx < len(descent_data):
                descent_speeds.append(speed)
            else:
                climb_speeds.append(speed)
                climb_powers.append(power)
            
            writer.add_record(
                timestamp=timestamp,
                lat=lat,
                lon=lon,
                altitude=elevation,
                speed=speed,
                distance=point['position'],
                cadence=cadence,
                power=power
            )
        
        # Calculate stats
        run_duration = len(run_data) * 0.1
        total_distance = max(all_positions) if all_positions else 0
        avg_speed = sum(all_speeds) / len(all_speeds) if all_speeds else 0
        max_speed = max(all_speeds) if all_speeds else 0
        avg_cadence = sum(all_cadences) / len(all_cadences) if all_cadences else 0
        max_cadence = max(all_cadences) if all_cadences else 0
        avg_power = sum(all_powers) / len(all_powers) if all_powers else 0
        max_power = max(all_powers) if all_powers else 0
        elevation_loss = max(all_elevations) - min(all_elevations) if all_elevations else 0
        
        max_descent = max(descent_speeds) if descent_speeds else 0
        avg_descent = sum(descent_speeds) / len(descent_speeds) if descent_speeds else 0
        avg_climb = sum(climb_speeds) / len(climb_speeds) if climb_speeds else 0
        avg_climb_power = sum(climb_powers) / len(climb_powers) if climb_powers else 0
        
        # Add lap
        run_end_time = base_time + int(global_time + run_duration)
        writer.add_lap(
            timestamp=run_end_time,
            start_time=run_start_time,
            total_distance=int(total_distance * 100),
            total_elapsed_time=int(run_duration * 1000),
            avg_speed=int(avg_speed * 100),
            max_speed=int(max_speed * 100),
            avg_cadence=int(avg_cadence),
            max_cadence=int(max_cadence),
            avg_power=int(avg_power),
            max_power=int(max_power),
            total_descent=int(elevation_loss * 100),
            num_laps=run_num
        )
        
        print(f'  ⬇️ Descent: {max_descent*3.6:.1f} km/h max, {avg_descent*3.6:.1f} km/h avg')
        print(f'  ⬆️ Climb: {avg_climb*3.6:.1f} km/h, {avg_climb_power:.0f}W')
        
        all_stats.append({
            'pressure': pressure_bar,
            'max_descent': max_descent * 3.6,
            'avg_descent': avg_descent * 3.6,
        })
        
        global_time += run_duration + 1
    
    # Add session (covers entire activity)
    total_time = global_time
    writer.add_session(
        timestamp=base_time + int(total_time),
        start_time=base_time,
        total_distance=int(STREET_LENGTH * 100 * 3),
        total_elapsed_time=int(total_time * 1000),
        avg_speed=0,
        max_speed=0,
        avg_cadence=0,
        max_cadence=0,
        avg_power=0,
        max_power=0,
        total_descent=int(ELEVATION_DROP * 100 * 3),
        num_laps=3
    )
    
    # Write file
    writer.write()
    
    print(f'\n✅ FIT File: {fit_path}')
    print(f'   Duration: {total_time:.0f} seconds')
    print(f'\n📊 Pressure Effect (Descent Speed):')
    for stat in all_stats:
        print(f'   {stat["pressure"]} bar: {stat["max_descent"]:.1f} km/h max')
    print('\n✅ Ready for Strava!')


if __name__ == '__main__':
    generate()
