import struct

fit_file = 'dart_test_output.fit'

try:
    with open(fit_file, 'rb') as f:
        # Read FIT file header
        header_size = struct.unpack('B', f.read(1))[0]
        protocol_version = struct.unpack('B', f.read(1))[0]
        profile_version = struct.unpack('<H', f.read(2))[0]
        data_size = struct.unpack('<I', f.read(4))[0]
        data_type = f.read(4).decode('ascii', errors='ignore')
        
        print("=== FIT FILE HEADER ===")
        print(f"Header Size: {header_size}")
        print(f"Protocol Version: {protocol_version}")
        print(f"Profile Version: {profile_version}")
        print(f"Data Size: {data_size} bytes")
        print(f"Data Type: {data_type}")
        print(f"Total File Size: {header_size + data_size + 2} bytes (including CRC)")
        
        # Try to read with fitdecode
        try:
            import fitdecode
            
            print(f"\n=== DECODED MESSAGES ===")
            
            messages = []
            with fitdecode.FitReader(fit_file) as fit:
                for frame in fit:
                    if isinstance(frame, fitdecode.FitDataMessage):
                        messages.append(frame)

            print(f"Total data messages: {len(messages)}")
            
            # Count message types
            message_types = {}
            for msg in messages:
                msg_type = msg.name
                message_types[msg_type] = message_types.get(msg_type, 0) + 1
            
            print(f"\nMessage breakdown:")
            for msg_type, count in sorted(message_types.items()):
                print(f"  {msg_type}: {count}")
            
            # Look for LAP messages
            lap_count = 0
            for msg in messages:
                if msg.name == 'lap':
                    lap_count += 1
                    print(f"\nLap {lap_count}:")
                    for field in ['avg_speed', 'avg_power', 'total_distance', 'total_elapsed_time']:
                        if msg.has_field(field):
                            print(f"  {field}: {msg.get_value(field)}")
            
        except Exception as e:
            print(f"\nError decoding with fitdecode: {e}")
            print("Ensure 'fitdecode' is installed: pip install fitdecode")
        
except Exception as e:
    print(f"Error reading file: {e}")
