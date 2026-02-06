import struct

fit_file = 'test_data/agr.fit'

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
        
        # Try to read with fit_tool
        try:
            from fit_tool import FitFileDecoder
            
            f.seek(0)
            data = f.read()
            messages = FitFileDecoder().decode(data)
            
            print(f"\n=== DECODED MESSAGES ===")
            print(f"Total messages: {len(messages)}")
            
            # Count message types
            message_types = {}
            for msg in messages:
                msg_type = type(msg).__name__
                message_types[msg_type] = message_types.get(msg_type, 0) + 1
            
            print(f"\nMessage breakdown:")
            for msg_type, count in sorted(message_types.items()):
                print(f"  {msg_type}: {count}")
            
            # Look for LAP messages
            from fit_tool import LapMessage
            lap_count = 0
            for msg in messages:
                if isinstance(msg, LapMessage):
                    lap_count += 1
                    print(f"\nLap {lap_count}:")
                    print(f"  avgSpeed: {msg.avgSpeed}")
                    print(f"  avgPower: {msg.avgPower}")
                    print(f"  totalDistance: {msg.totalDistance}")
                    print(f"  totalElapsedTime: {msg.totalElapsedTime}")
            
        except Exception as e:
            print(f"\nError decoding with fit_tool: {e}")
            print("File appears to be valid FIT format but may need fit_tool SDK")
        
except Exception as e:
    print(f"Error reading file: {e}")
