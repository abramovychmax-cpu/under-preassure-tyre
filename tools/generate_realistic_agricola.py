#!/usr/bin/env python3
"""
Realistic physics-based FIT file generation for Agricola Street descent.

Simulates actual cycling physics:
- Gravitational component down slope
- Pressure-dependent rolling resistance (Crr)
- Air drag (Cd)
- Pedaling power on ascent (up to 400W sustainable)
- Braking dynamics
- Single FIT file with 3 runs at different tire pressures
"""

import struct
import json
import math
import random
from datetime import datetime, timedelta
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
GRAVITY = 9.81  # m/s^2
TOTAL_MASS = 90  # kg (rider + bike)
AIR_DENSITY = 1.225  # kg/m^3
CD = 1.1  # drag coefficient
FRONTAL_AREA = 0.5  # m^2
RIDER_HEIGHT = 1.75  # m (for realism)

# Agricola Street parameters
STREET_LENGTH = 500.0  # meters
ELEVATION_DROP = 25.0  # meters
STREET_GRADIENT = ELEVATION_DROP / STREET_LENGTH  # ~0.05 = 5%
STREET_ANGLE = math.atan(STREET_GRADIENT)  # radians

class PhysicsSimulator:
    """Simulates cycling physics on Agricola Street descent."""
    
    def __init__(self, tire_pressure_bar):
        """
        Initialize with tire pressure.
        
        Args:
            tire_pressure_bar: Pressure in bar (3.5, 4.4, or 5.0)
        """
        self.pressure = tire_pressure_bar
        self.mass = TOTAL_MASS
        
        # Rolling resistance coefficient varies with pressure
        # Lower pressure = higher Crr (worse rolling)
        # Higher pressure = lower Crr (better rolling)
        # Formula: Crr = 0.008 - 0.0006 * (P - 3.0) where P is in bar
        # This gives: 3.5bar -> 0.0067, 4.4bar -> 0.0046, 5.0bar -> 0.0038
        self.crr = max(0.003, 0.008 - 0.0006 * (tire_pressure_bar - 3.0))
    
    def _rolling_resistance(self, speed_ms):
        """Calculate rolling resistance force in Newtons."""
        normal_force = self.mass * GRAVITY * math.cos(STREET_ANGLE)
        return self.crr * normal_force
    
    def _air_drag(self, speed_ms):
        """Calculate air drag force in Newtons."""
        return 0.5 * AIR_DENSITY * CD * FRONTAL_AREA * (speed_ms ** 2)
    
    def _gravity_component(self):
        """Gravitational component down the slope in Newtons."""
        return self.mass * GRAVITY * math.sin(STREET_ANGLE)
    
    def simulate_descent(self, duration_seconds=40):
        """
        Simulate coasting down without pedaling, then braking.
        
        Args:
            duration_seconds: How long to simulate
            
        Returns:
            List of (time, position, speed, power, elevation) tuples
        """
        data = []
        speed = 0.0  # Start from standing start
        position = 0.0  # Start at top (0m)
        max_speed_achieved = 0.0
        
        dt = 0.1  # 0.1 second time steps
        num_steps = int(duration_seconds / dt)
        
        for step in range(num_steps):
            time = step * dt
            
            # Calculate forces
            gravity_force = self._gravity_component()
            rolling_force = self._rolling_resistance(speed)
            drag_force = self._air_drag(speed)
            
            # Braking starts at 80% of street length (400m)
            brake_position = STREET_LENGTH * 0.8
            if position >= brake_position:
                # Braking force (stronger the faster you go)
                brake_intensity = (position - brake_position) / (STREET_LENGTH - brake_position)
                brake_force = 400 * brake_intensity  # Up to 400N braking
            else:
                brake_force = 0
            
            # Net force equation: F_net = F_gravity - F_rolling - F_drag - F_brake
            net_force = gravity_force - rolling_force - drag_force - brake_force
            
            # Acceleration a = F / m
            acceleration = net_force / self.mass
            
            # Update speed (don't go backwards)
            speed = max(0, speed + acceleration * dt)
            max_speed_achieved = max(max_speed_achieved, speed)
            
            # Update position
            position = min(STREET_LENGTH, position + speed * dt)
            
            # Power output (negative = braking energy)
            power = int(speed * brake_force)  # Braking dissipates energy
            
            # Elevation calculation
            elevation = 100.0 - (position / STREET_LENGTH) * ELEVATION_DROP
            
            # Cadence while coasting (very low)
            cadence = 0 if speed < 5 else int(30 + (speed - 5) * 2)
            
            data.append({
                'time': time,
                'position': position,
                'speed': speed,
                'power': power,
                'elevation': elevation,
                'cadence': min(120, cadence),
            })
            
            # Stop when reached bottom and nearly stopped
            if position >= STREET_LENGTH and speed < 1.0:
                break
        
        return data, max_speed_achieved
    
    def simulate_turnaround(self, duration_seconds=5):
        """Simulate turning around at bottom."""
        data = []
        for i in range(int(duration_seconds * 10)):
            data.append({
                'time': i * 0.1,
                'position': STREET_LENGTH,
                'speed': 0.0,
                'power': 0,
                'elevation': 75.0,
                'cadence': 0,
            })
        return data
    
    def simulate_climb(self, duration_seconds=60):
        """
        Simulate pedaling up the hill.
        
        Args:
            duration_seconds: How long to climb
            
        Returns:
            List of simulation data points
        """
        data = []
        position = STREET_LENGTH  # Start at bottom
        speed = 2.0  # Start with walking speed
        
        # Sustainable pedaling power for 90kg rider: ~300W average
        # Can vary from 200W (easy) to 400W (hard effort)
        pedal_power = 300  # Watts
        
        dt = 0.1
        num_steps = int(duration_seconds / dt)
        
        for step in range(num_steps):
            time = step * dt
            
            # Going up slope
            gravity_force = self._gravity_component()  # Now opposing motion
            rolling_force = self._rolling_resistance(speed)
            drag_force = self._air_drag(speed)
            
            # Power to force conversion: Power = Force * velocity
            # Pedaling force = Power / speed (but cap it)
            if speed > 0.5:
                pedal_force = pedal_power / speed
            else:
                pedal_force = 200  # Can't generate infinite force
            
            # Net force: F_pedal - F_gravity - F_rolling - F_drag
            net_force = pedal_force - gravity_force - rolling_force - drag_force
            
            # Acceleration
            acceleration = net_force / self.mass
            
            # Update speed
            speed = max(0.5, speed + acceleration * dt)
            
            # Position (going backwards up the hill)
            position = max(0, position - speed * dt)
            
            # Elevation
            elevation = 100.0 - (position / STREET_LENGTH) * ELEVATION_DROP
            
            # Cadence while pedaling (90 RPM typical)
            cadence = int(85 + random.gauss(0, 5))
            cadence = max(70, min(110, cadence))
            
            # Power is what we're pedaling at
            power = pedal_power + int(random.gauss(0, 10))
            
            data.append({
                'time': time,
                'position': position,
                'speed': speed,
                'power': power,
                'elevation': elevation,
                'cadence': cadence,
            })
            
            # Stop when reached top
            if position <= 0:
                break
        
        return data


class FITFileWriter:
    """Write FIT format files."""
    
    def __init__(self, filepath):
        self.filepath = filepath
        self.data_buffer = b''
    
    def _crc16(self, data):
        """Calculate CRC16 for FIT data."""
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
        """Add file ID message."""
        msg = struct.pack('<BHHHQ', 0, type_, manufacturer, product, serial_number)
        self.data_buffer += bytes([0x40, 0]) + msg
    
    def add_record(self, timestamp, lat, lon, altitude, speed, distance, cadence, power):
        """Add a record message (sensor data point)."""
        msg = struct.pack('<IiiIIBH',
            timestamp & 0xFFFFFFFF,
            int(lat * 2147483648.0 / 180.0),  # semicircles (signed)
            int(lon * 2147483648.0 / 180.0),  # semicircles (signed)
            int(speed) & 0xFFFFFFFF,
            int(distance) & 0xFFFFFFFF,
            int(cadence) & 0xFF,
            int(power) & 0xFFFF
        )
        self.data_buffer += bytes([0x40, 20]) + msg
    
    def add_lap(self, timestamp, start_time, total_distance, total_elapsed_time, avg_speed, max_speed,
                avg_cadence, max_cadence, total_ascent, total_descent, sport, avg_power, max_power):
        """Add a lap message."""
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
                    avg_cadence, max_cadence, total_ascent, total_descent, sport, avg_power, max_power, num_laps):
        """Add a session message."""
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
        """Write the FIT file."""
        with open(self.filepath, 'wb') as f:
            data_crc = self._crc16(self.data_buffer)
            data_size = len(self.data_buffer)
            
            # Write header
            f.write(bytes([FIT_HEADER_SIZE, FIT_PROTOCOL_VERSION]))
            f.write(struct.pack('<H', FIT_PROFILE_VERSION))
            f.write(struct.pack('<I', data_size))
            f.write(b'.FIT')
            
            # Write data
            f.write(self.data_buffer)
            
            # Write footer (CRC16)
            f.write(struct.pack('<H', data_crc))


def generate_single_fit_file_with_three_runs():
    """Generate one FIT file with 3 runs at different tire pressures."""
    
    # Agricola Street location (Warsaw, Poland)
    start_lat = 52.2420
    start_lon = 21.0455
    end_lat = 52.2395
    end_lon = 21.0470
    
    # Three pressure configurations to test
    pressures_bar = [
        (3.5, 3.5, 1),  # Low pressure
        (4.4, 4.4, 2),  # Medium pressure
        (5.0, 5.0, 3),  # High pressure
    ]
    
    # Create FIT file writer
    output_dir = Path('assets/simulations')
    output_dir.mkdir(parents=True, exist_ok=True)
    fit_path = output_dir / 'agricola_3runs_realistic.fit'
    
    fit_writer = FITFileWriter(str(fit_path))
    
    # Add file ID
    fit_writer.add_file_id(
        type_=4,
        manufacturer=1,
        product=0,
        serial_number=12345,
        time_created=int(datetime.now().timestamp())
    )
    
    start_time = int(datetime.now().timestamp())
    global_time = 0
    run_results = []
    
    # Generate each run
    for front_bar, rear_bar, run_num in pressures_bar:
        print(f'\n✓ Simulating Run {run_num}: {front_bar}/{rear_bar} bar...')
        
        # Create physics simulator for this pressure
        simulator = PhysicsSimulator(front_bar)
        
        # Phase 1: Descent (coasting down)
        descent_data, max_descent_speed = simulator.simulate_descent(duration_seconds=60)
        descent_duration = len(descent_data) * 0.1
        
        # Phase 2: Turnaround at bottom
        turnaround_data = simulator.simulate_turnaround(duration_seconds=5)
        
        # Phase 3: Climb back up (pedaling)
        climb_data = simulator.simulate_climb(duration_seconds=90)
        climb_duration = len(climb_data) * 0.1
        
        all_run_data = descent_data + turnaround_data + climb_data
        
        # GPS path for descent
        start_position = 0.0
        end_position = STREET_LENGTH
        
        # Write records to FIT
        distances = []
        speeds = []
        cadences = []
        powers = []
        elevations = []
        
        # Track descent and climb separately
        descent_speeds = []
        climb_speeds = []
        climb_powers = []
        
        run_start_time = global_time
        
        for idx, data_point in enumerate(all_run_data):
            time_offset = int(data_point['time'])
            
            # Interpolate GPS based on position along street
            progress = min(1.0, data_point['position'] / STREET_LENGTH)
            lat = start_lat + (end_lat - start_lat) * progress
            lon = start_lon + (end_lon - start_lon) * progress
            
            elevation = data_point['elevation']
            speed = data_point['speed']
            cadence = data_point['cadence']
            power = data_point['power']
            
            # Track metrics
            distances.append(data_point['position'])
            speeds.append(speed)
            cadences.append(cadence)
            powers.append(power)
            elevations.append(elevation)
            
            # Track descent vs climb
            if idx < len(descent_data):
                descent_speeds.append(speed)
            elif idx < len(descent_data) + len(turnaround_data):
                pass  # Turnaround phase
            else:
                climb_speeds.append(speed)
                climb_powers.append(power)
            
            # Add record
            fit_writer.add_record(
                timestamp=int(start_time + global_time + time_offset),
                lat=lat,
                lon=lon,
                altitude=int(elevation * 100),  # cm
                speed=int(speed * 1000),  # mm/s
                distance=int(data_point['position'] * 100),  # cm
                cadence=cadence,
                power=power
            )
        
        # Calculate run statistics
        run_duration = len(all_run_data) * 0.1  # 0.1 second per step
        total_distance = max(distances) if distances else 0
        avg_speed = sum(speeds) / len(speeds) if speeds else 0
        max_speed = max(speeds) if speeds else 0
        avg_cadence = sum(cadences) / len(cadences) if cadences else 0
        max_cadence = max(cadences) if cadences else 0
        avg_power = sum(powers) / len(powers) if powers else 0
        max_power = max(powers) if powers else 0
        elevation_loss = max(elevations) - min(elevations) if elevations else 0
        
        # Descent stats
        max_descent = max(descent_speeds) if descent_speeds else 0
        avg_descent_speed = sum(descent_speeds) / len(descent_speeds) if descent_speeds else 0
        
        # Climb stats
        avg_climb_speed = sum(climb_speeds) / len(climb_speeds) if climb_speeds else 0
        avg_climb_power = sum(climb_powers) / len(climb_powers) if climb_powers else 0
        
        # Add lap message
        run_end_time = global_time + len(all_run_data) * 0.1
        fit_writer.add_lap(
            timestamp=start_time + int(run_end_time),
            start_time=start_time + run_start_time,
            total_distance=int(total_distance * 100),  # cm
            total_elapsed_time=int(run_duration * 1000),  # ms
            avg_speed=int(avg_speed * 1000),  # mm/s
            max_speed=int(max_speed * 1000),
            avg_cadence=int(avg_cadence),
            max_cadence=int(max_cadence),
            total_ascent=int(elevation_loss * 50),  # Half the descent
            total_descent=int(elevation_loss * 100),
            sport=1,  # cycling
            avg_power=int(avg_power),
            max_power=int(max_power)
        )
        
        print(f'  ⬇️ Descent ({descent_duration:.0f}s):')
        print(f'     Max: {max_descent:.1f} m/s ({max_descent*3.6:.1f} km/h)')
        print(f'     Avg: {avg_descent_speed:.1f} m/s ({avg_descent_speed*3.6:.1f} km/h)')
        print(f'  ⬆️ Climb ({climb_duration:.0f}s):')
        print(f'     Avg: {avg_climb_speed:.1f} m/s ({avg_climb_speed*3.6:.1f} km/h)')
        print(f'     Power: {avg_climb_power:.0f}W')
        
        run_results.append({
            'pressure': f'{front_bar}/{rear_bar} bar',
            'max_descent_speed_kmh': max_descent_speed * 3.6,
            'duration_s': run_duration,
            'avg_speed_kmh': avg_speed * 3.6,
        })
        
        global_time += len(all_run_data) * 0.1 + 5  # Add gap between runs
    
    # Add session message
    fit_writer.add_session(
        timestamp=start_time + int(global_time),
        start_time=start_time,
        total_distance=0,
        total_elapsed_time=int(global_time * 1000),
        avg_speed=0,
        max_speed=0,
        avg_cadence=0,
        max_cadence=0,
        total_ascent=0,
        total_descent=0,
        sport=1,
        avg_power=0,
        max_power=0,
        num_laps=3
    )
    
    # Write FIT file
    fit_writer.write_file()
    
    print(f'\n✓ FIT file generated: {fit_path}')
    print(f'\nResults Summary:')
    print('-' * 70)
    for result in run_results:
        print(f'  {result["pressure"]}: {result["max_descent_speed_kmh"]:.1f} km/h max | '
              f'{result["duration_s"]:.0f}s | {result["avg_speed_kmh"]:.1f} km/h avg')
    
    # Create metadata file
    metadata = {
        'simulation_type': 'Realistic physics-based',
        'street': 'Agricola Street, Warsaw',
        'street_length_m': STREET_LENGTH,
        'elevation_drop_m': ELEVATION_DROP,
        'gradient_percent': STREET_GRADIENT * 100,
        'total_mass_kg': TOTAL_MASS,
        'runs': [
            {
                'pressure_bar': f'{r["pressure"]}',
                'max_descent_speed_kmh': r['max_descent_speed_kmh'],
                'duration_s': r['duration_s'],
                'avg_speed_kmh': r['avg_speed_kmh'],
            }
            for r in run_results
        ],
    }
    
    metadata_path = output_dir / 'agricola_3runs_realistic_metadata.json'
    with open(metadata_path, 'w') as f:
        json.dump(metadata, f, indent=2)
    
    print(f'✓ Metadata saved: {metadata_path}')


if __name__ == '__main__':
    print('=' * 70)
    print('Realistic Physics-Based FIT File Generator')
    print('Agricola Street Descent - 3 Runs')
    print('=' * 70)
    generate_single_fit_file_with_three_runs()
    print('=' * 70)
