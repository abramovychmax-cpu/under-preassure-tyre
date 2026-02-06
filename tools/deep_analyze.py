#!/usr/bin/env python3
"""
Deeply analyze a FIT file's message structure and print a complete blueprint.
This script iterates through every message and logs its type, name, and fields.
"""
import sys
import fitparse

def deep_analyze(filepath):
    """
    Parses a FIT file and prints the detailed structure of every message.
    """
    try:
        print(f"\n{'='*80}")
        print(f"DEEP ANALYSIS OF: {filepath}")
        print(f"{'='*80}")

        fitfile = fitparse.FitFile(filepath, check_crc=False)
        
        definitions = {}
        
        for i, message in enumerate(fitfile.get_messages()):
            print(f"\n--- Message #{i+1} ---")
            
            if message.mesg_type.name == 'definition':
                # It's a definition message
                local_type = message.mesg_type.local_mesg_num
                global_num = message.mesg_num
                name = message.name
                
                definitions[local_type] = name
                
                print(f"Type:      DEFINITION")
                print(f"Local Type: {local_type}")
                print(f"Global Num: {global_num} ({name})")
                
                fields = [f.name for f in message.fields]
                print(f"Fields ({len(fields)}): {', '.join(fields)}")

            else:
                # It's a data message
                local_type = message.mesg_type.local_mesg_num
                name = definitions.get(local_type, "UNKNOWN")

                print(f"Type:      DATA")
                print(f"Local Type: {local_type} ({name})")
                
                fields = {f.name: f.value for f in message.fields}
                field_names = sorted(fields.keys())
                print(f"Fields ({len(field_names)}): {', '.join(field_names)}")

    except Exception as e:
        print(f"\n\nERROR: Could not parse file '{filepath}'. Reason: {e}")
        sys.exit(1)

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python deep_analyze.py <path_to_fit_file>")
        sys.exit(1)
        
    filepath = sys.argv[1]
    deep_analyze(filepath)
