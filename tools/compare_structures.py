#!/usr/bin/env python3
"""Compare FIT file structures to identify missing required fields"""

import fitparse
import sys

def analyze_fit(filepath):
    """Extract message structure from FIT file"""
    try:
        fit = fitparse.FitFile(filepath, check_crc=False)  # Skip CRC check - fitparse bug
        
        structure = {
            'file_id': [],
            'record': [],
            'lap': [],
            'session': [],
            'activity': []
        }
        
        for msg in fit.get_messages():
            if msg.name in structure:
                fields = {f.name: f.value for f in msg.fields}
                structure[msg.name].append(fields)
        
        return structure
    except Exception as e:
        print(f"Error parsing {filepath}: {e}")
        return None

def print_comparison(name1, struct1, name2, struct2):
    """Print a side-by-side comparison of two FIT structures."""
    all_msg_types = sorted(list(set(struct1.keys()) | set(struct2.keys())))

    print(f"\n{'='*80}")
    print(f"FIT FILE COMPARISON")
    print(f"{'='*80}")
    print(f"{name1:<38} | {name2:<38}")
    print(f"{'-'*38} | {'-'*38}")

    for msg_type in all_msg_types:
        msgs1 = struct1.get(msg_type, [])
        msgs2 = struct2.get(msg_type, [])
        
        status1 = f"{len(msgs1)} msg(s)" if msgs1 else "MISSING"
        status2 = f"{len(msgs2)} msg(s)" if msgs2 else "MISSING"
        
        print(f"\n{msg_type.upper():<38} | {msg_type.upper():<38}")
        print(f"{status1:<38} | {status2:<38}")

        if msgs1 and msgs2:
            fields1 = set(msgs1[0].keys())
            fields2 = set(msgs2[0].keys())
            all_fields = sorted(list(fields1 | fields2))
            
            print(f"{'  Fields:':<38} | {'  Fields:':<38}")
            for field in all_fields:
                f_status1 = "✓" if field in fields1 else "✗"
                f_status2 = "✓" if field in fields2 else "✗"
                print(f"  {f_status1} {field:<35} |   {f_status2} {field:<34}")


if __name__ == '__main__':
    if len(sys.argv) != 3:
        print("Usage: python compare_structures.py <file1.fit> <file2.fit>")
        sys.exit(1)

    file1_path = sys.argv[1]
    file2_path = sys.argv[2]

    print(f"Analyzing {file1_path}...")
    struct1 = analyze_fit(file1_path)
    
    print(f"Analyzing {file2_path}...")
    struct2 = analyze_fit(file2_path)

    if struct1 and struct2:
        print_comparison(file1_path.split('/')[-1], struct1, file2_path.split('\\')[-1], struct2)

