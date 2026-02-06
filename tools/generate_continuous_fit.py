#!/usr/bin/env python3
"""
Continuous realistic physics-based FIT file for Agricola Street.

Single uninterrupted file with 3 runs at different pressures.
App detects descent/climb phases by analyzing velocity and elevation.
Strava-compatible format.
"""

import struct
import json
import math
import random
from datetime import datetime
from pathlib import Path

# FIT file constants
FIT_HEADER_SIZE = 14
FIT_PROTOCOL_VERSION = 0x20
FIT_PROFILE_VERSION = 2314
DATA_TYPE_FILE_ID = 0
DATA_TYPE_RECORD = 20
DATA_TYPE_LAP = 21
DATA_TYPE_SESSION = 34

# Physics constants
GRAVITY = 9.81
TOTAL_MASS = 90  # kg
AIR_DENSITY = 1.225
CD = 1.1
FRONTAL_AREA = 0.5

# Agricola Street
STREET_LENGTH = 500.0
ELEVATION_DROP = 25.0
STREET_GRADIENT = ELEVATION_DROP / STREET_LENGTH
STREET_ANGLE = math.atan(STREET_GRADIENT)


class PhysicsSimulator:
    """Realistic cycling physics simulation."""
    
    def __init__(self, tire_pressure_bar):
        self.pressure = tire_pressure_bar
        self.mass = TOTAL_MASS
        # Crr formula: lower pressure = worse rolling
        self.crr = max(0.003, 0.008 - 0.0006 * (tire_pressure_bar - 3.0))
    
    def _rolling_resistance(self, speed_ms):
        normal_force = self.mass * GRAVITY * math.cos(STREET_ANGLE)
        return self.crr * normal_force
    
    def _air_drag(self, speed_ms):
        return 0.5 * AIR_DENSITY * CD * FRONTAL_AREA * (speed_ms ** 2)
    
    def _gravity_component(self):
        return self.mass * GRAVITY * math.sin(STREET_ANGLE)
    
    def simulate_descent(self, duration_seconds=40):
        """Coasting down without pedaling."""
        data = []
        speed = 0.0
        position = 0.0
        dt = 0.1
        
        for step in range(int(duration_seconds / dt)):
            time = step * dt
            
            gravity_force = self._gravity_component()
            rolling_force = self._rolling_resistance(speed)
            drag_force = self._air_drag(speed)
            
            # Braking at 80% of street
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
            power = int(speed * brake_force)  # Braking dissipation
            
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
        """Pedaling back up."""
        data = []
        position = STREET_LENGTH
        speed = 2.0
        pedal_power = 300  # Watts
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


class FITFileWriter:
    """Write FIT format files with proper CRC."""
    
    def __init__(self, filepath):
        self.filepath = filepath
        self.data_buffer = b''
        self.timestamp_counter = 0
    
    def _crc16(self, data):
        crc = 0
        for byte in data:
            crc = ((crc << 8) ^ byte) & 0xFFFF
            for _ in range(8):
                if crc & 0x8000:
                    crc = ((crc << 1) ^ 0xCC01) & 0xFFFF
                else:
                    crc = (crc << 1) & 0xFFFF
        return crc
    
    def add_file_id(self, type_=4, manufacturer=1, product=0, serial_number=0, time_created=0):
        msg = struct.pack('<BHHHQ', 0, type_, manufacturer, product, serial_number)
        self.data_buffer += bytes([0x40, 0]) + msg
    
    def add_record(self, timestamp, lat, lon, altitude, speed, distance, cadence, power):
        msg = struct.pack('<IiiIIBH',
            int(timestamp) & 0xFFFFFFFF,
            int(lat * 2147483648.0 / 180.0),
            int(lon * 2147483648.0 / 180.0),
            int(speed) & 0xFFFFFFFF,
            int(distance) & 0xFFFFFFFF,
            int(cadence) & 0xFF,
            int(power) & 0xFFFF
        )
        self.data_buffer += bytes([0x40, 20]) + msg
    
    def add_lap(self, timestamp, start_time, total_distance, total_elapsed_time, avg_speed, max_speed,
                avg_cadence, max_cadence, total_descent, sport, avg_power, max_power):
        msg = struct.pack('<IIIIIIHHHH',
            int(timestamp) & 0xFFFFFFFF,
            int(start_time) & 0xFFFFFFFF,
            int(total_elapsed_time) & 0xFFFFFFFF,
            int(total_distance) & 0xFFFFFFFF,
            int(avg_speed) & 0xFFFFFFFF,
            int(max_speed) & 0xFFFFFFFF,
            int(sport) & 0xFFFF,
            int(avg_cadence) & 0xFF,
            int(max_cadence) & 0xFF,
            int(total_descent) & 0xFFFF
        )
        self.data_buffer += bytes([0x40, 21]) + msg
    
    def add_session(self, timestamp, start_time, total_distance, total_elapsed_time, avg_speed, max_speed,
                    avg_cadence, max_cadence, total_descent, sport, avg_power, max_power, num_laps):
        msg = struct.pack('<IIIIIIHHHH',
            int(timestamp) & 0xFFFFFFFF,
            int(start_time) & 0xFFFFFFFF,
            int(total_elapsed_time) & 0xFFFFFFFF,
            int(total_distance) & 0xFFFFFFFF,
            int(avg_speed) & 0xFFFFFFFF,
            int(max_speed) & 0xFFFFFFFF,
            int(sport) & 0xFFFF,
            int(avg_cadence) & 0xFF,
            int(max_cadence) & 0xFF,
            int(total_descent) & 0xFFFF
        )
        self.data_buffer += bytes([0x40, 34]) + msg
    
    def write_file(self):
        with open(self.filepath, 'wb') as f:
            data_crc = self._crc16(self.data_buffer)
            data_size = len(self.data_buffer)
            
            # Header
            f.write(bytes([FIT_HEADER_SIZE, FIT_PROTOCOL_VERSION]))
            f.write(struct.pack('<H', FIT_PROFILE_VERSION))
            f.write(struct.pack('<I', data_size))
            f.write(b'.FIT')
            
            # Data
            f.write(self.data_buffer)
            
            # Footer
            f.write(struct.pack('<H', data_crc))


def generate_continuous_fit():
    """Generate ONE continuous FIT file with 3 runs."""
    
    start_lat = 52.2420
    start_lon = 21.0455
    end_lat = 52.2395
    end_lon = 21.0470
    
    pressures = [
        (3.5, 1),
        (4.4, 2),
        (5.0, 3),
    ]
    
    output_dir = Path('assets/simulations')
    output_dir.mkdir(parents=True, exist_ok=True)
    fit_path = output_dir / 'agricola_continuous.fit'
    
    fit_writer = FITFileWriter(str(fit_path))
    fit_writer.add_file_id(
        type_=4,
        manufacturer=1,
        product=0,
        serial_number=12345,
        time_created=int(datetime.now().timestamp())
    )
    
    start_timestamp = int(datetime.now().timestamp())
    global_time = 0
    all_stats = []
    
    # Generate 3 continuous runs
    for front_bar, run_num in pressures:
        print(f'\n✓ Run {run_num}: {front_bar} bar (continuous)')
        
        simulator = PhysicsSimulator(front_bar)
        
        # Descent phase
        descent_data = simulator.simulate_descent(duration_seconds=60)
        descent_duration = len(descent_data) * 0.1
        
        # Climb phase (no break - continuous)
        climb_data = simulator.simulate_climb(duration_seconds=90)
        climb_duration = len(climb_data) * 0.1
        
        run_data = descent_data + climb_data
        run_start_time = global_time
        
        # Write all records for this run
        all_speeds = []
        all_powers = []
        all_cadences = []
        all_elevations = []
        all_positions = []
        descent_speeds = []
        climb_speeds = []
        climb_powers = []
        
        for idx, point in enumerate(run_data):
            time_offset = point['time']
            
            # GPS interpolation
            progress = min(1.0, point['position'] / STREET_LENGTH)
            lat = start_lat + (end_lat - start_lat) * progress
            lon = start_lon + (end_lon - start_lon) * progress
            
            elevation = point['elevation']
            speed = point['speed']
            cadence = point['cadence']
            power = point['power']
            
            all_speeds.append(speed)
            all_powers.append(power)
            all_cadences.append(cadence)
            all_elevations.append(elevation)
            all_positions.append(point['position'])
            
            # Track descent vs climb
            if idx < len(descent_data):
                descent_speeds.append(speed)
            else:
                climb_speeds.append(speed)
                climb_powers.append(power)
            
            # Add record to FIT
            fit_writer.add_record(
                timestamp=start_timestamp + int(global_time + time_offset),
                lat=lat,
                lon=lon,
                altitude=int(elevation * 100),
                speed=int(speed * 1000),
                distance=int(point['position'] * 100),
                cadence=cadence,
                power=power
            )
        
        # Stats
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
        avg_descent_speed = sum(descent_speeds) / len(descent_speeds) if descent_speeds else 0
        avg_climb_speed = sum(climb_speeds) / len(climb_speeds) if climb_speeds else 0
        avg_climb_power = sum(climb_powers) / len(climb_powers) if climb_powers else 0
        
        # Add lap
        run_end_time = global_time + len(run_data) * 0.1
        fit_writer.add_lap(
            timestamp=start_timestamp + int(run_end_time),
            start_time=start_timestamp + run_start_time,
            total_distance=int(total_distance * 100),
            total_elapsed_time=int(run_duration * 1000),
            avg_speed=int(avg_speed * 1000),
            max_speed=int(max_speed * 1000),
            avg_cadence=int(avg_cadence),
            max_cadence=int(max_cadence),
            total_descent=int(elevation_loss * 100),
            sport=1,
            avg_power=int(avg_power),
            max_power=int(max_power)
        )
        
        print(f'  ⬇️ Descent ({descent_duration:.0f}s):')
        print(f'     Max: {max_descent*3.6:.1f} km/h | Avg: {avg_descent_speed*3.6:.1f} km/h')
        print(f'  ⬆️ Climb ({climb_duration:.0f}s):')
        print(f'     Speed: {avg_climb_speed*3.6:.1f} km/h | Power: {avg_climb_power:.0f}W')
        
        all_stats.append({
            'pressure_bar': front_bar,
            'max_descent_kmh': max_descent * 3.6,
            'avg_descent_kmh': avg_descent_speed * 3.6,
            'avg_climb_kmh': avg_climb_speed * 3.6,
            'avg_climb_power': avg_climb_power,
            'total_duration_s': run_duration,
        })
        
        global_time = run_end_time + 1  # Small gap between runs (1 second)
    
    # Add session (covers all 3 runs)
    fit_writer.add_session(
        timestamp=start_timestamp + int(global_time),
        start_time=start_timestamp,
        total_distance=0,
        total_elapsed_time=int(global_time * 1000),
        avg_speed=0,
        max_speed=0,
        avg_cadence=0,
        max_cadence=0,
        total_descent=0,
        sport=1,
        avg_power=0,
        max_power=0,
        num_laps=3
    )
    
    # Write FIT
    fit_writer.write_file()
    
    print(f'\n✅ Continuous FIT file: {fit_path}')
    print(f'   Total duration: {global_time:.0f} seconds (~{global_time/60:.1f} minutes)')
    print(f'\n📊 Summary (for app to detect descent phases):')
    print('   ' + '─' * 70)
    for stat in all_stats:
        print(f'   {stat["pressure_bar"]} bar: '
              f'⬇️ {stat["max_descent_kmh"]:.1f} km/h max | '
              f'⬆️ {stat["avg_climb_kmh"]:.1f} km/h climb')
    print('   ' + '─' * 70)
    
    # Metadata
    metadata = {
        'type': 'continuous_three_runs',
        'file': 'agricola_continuous.fit',
        'format': 'Single FIT file - app detects descent/climb by velocity + elevation',
        'street': 'Agricola Street, Warsaw, Poland',
        'street_length_m': STREET_LENGTH,
        'elevation_drop_m': ELEVATION_DROP,
        'total_mass_kg': TOTAL_MASS,
        'runs': all_stats,
        'total_duration_s': global_time,
        'strava_ready': True,
    }
    
    metadata_path = output_dir / 'agricola_continuous_metadata.json'
    with open(metadata_path, 'w') as f:
        json.dump(metadata, f, indent=2)
    
    print(f'✅ Metadata: {metadata_path}')
    print('\n🎯 Ready to upload to Strava!')


if __name__ == '__main__':
    print('=' * 70)
    print('Continuous Physics-Based FIT File Generator')
    print('3 Runs - NO STOPS - App detects descending phases')
    print('=' * 70)
    generate_continuous_fit()
    print('=' * 70)
