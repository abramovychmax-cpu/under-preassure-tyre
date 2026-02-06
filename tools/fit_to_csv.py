#!/usr/bin/env python3
"""
FIT → CSV exporter with improved logging and a message-count summary.

Creates one CSV per message type and a summary CSV listing message counts.

Usage:
    python fit_to_csv.py input.fit --out-dir out --verbose

Requirements:
    pip install fitparse

This variant prints debugging information to help determine why a FIT file
may not be producing output.
"""
import os
import sys
import argparse
import csv
from collections import OrderedDict

try:
    from fitparse import FitFile
except Exception:
    print('fitparse not installed. Run: python -m pip install fitparse', file=sys.stderr)
    sys.exit(2)


def write_csv_for_messages(fitfile_path, out_dir, verbose=False):
    if verbose:
        print('Python executable:', sys.executable)
        print('Opening FIT file:', fitfile_path)

    try:
        fit = FitFile(fitfile_path)
    except Exception as e:
        print('Failed to open FIT file:', e, file=sys.stderr)
        return False

    basename = os.path.splitext(os.path.basename(fitfile_path))[0]
    os.makedirs(out_dir, exist_ok=True)

    # Collect messages grouped by name
    groups = OrderedDict()
    msg_count = 0
    try:
        for msg in fit.get_messages():
            groups.setdefault(msg.name, []).append(msg)
            msg_count += 1
    except Exception as e:
        import traceback
        print('Error while iterating messages:', file=sys.stderr)
        traceback.print_exc()
        return False

    if verbose:
        print('Total messages parsed:', msg_count)

    # If no messages found, warn and return
    if not groups:
        print('No messages found in FIT file. The file may be empty or corrupted.', file=sys.stderr)
        return False

    created_files = []
    summary = []

    for name, msgs in groups.items():
        out_path = os.path.join(out_dir, f"{basename}_{name}.csv")
        # Build header from union of field names preserving order seen
        header = []
        for m in msgs:
            for f in m.fields:
                if f.name not in header:
                    header.append(f.name)

        # Write CSV
        try:
            with open(out_path, 'w', newline='', encoding='utf-8') as fh:
                writer = csv.writer(fh)
                writer.writerow(['message_name'] + header)

                for m in msgs:
                    row = [m.name]
                    # Build a map for quick lookup
                    fv = {f.name: f.value for f in m.fields}
                    for h in header:
                        v = fv.get(h)
                        # Represent lists and dicts in a readable way
                        if isinstance(v, (list, tuple)):
                            v = '|'.join(map(str, v))
                        elif isinstance(v, dict):
                            v = ';'.join(f"{k}={v[k]}" for k in v)
                        row.append(v)
                    writer.writerow(row)

            created_files.append(out_path)
            summary.append((name, len(msgs)))
            if verbose:
                print(f'Wrote {out_path} ({len(msgs)} messages)')
        except Exception as e:
            print(f'Failed to write {out_path}: {e}', file=sys.stderr)

    # Write summary CSV
    summary_path = os.path.join(out_dir, f"{basename}_message_counts.csv")
    try:
        with open(summary_path, 'w', newline='', encoding='utf-8') as sf:
            writer = csv.writer(sf)
            writer.writerow(['message_name', 'count'])
            for name, cnt in summary:
                writer.writerow([name, cnt])
        if verbose:
            print('Wrote summary:', summary_path)
        created_files.append(summary_path)
    except Exception as e:
        print('Failed to write summary CSV:', e, file=sys.stderr)

    # Final report
    print('Created files:')
    for p in created_files:
        print('  ', p)

    return True


def main():
    p = argparse.ArgumentParser()
    p.add_argument('fitfile', help='Input .fit file path')
    p.add_argument('--out-dir', '-o', default='out', help='Output directory')
    p.add_argument('--verbose', '-v', action='store_true', help='Verbose logging')
    args = p.parse_args()

    if not os.path.isfile(args.fitfile):
        print('Input FIT file not found:', args.fitfile, file=sys.stderr)
        sys.exit(1)

    ok = write_csv_for_messages(args.fitfile, args.out_dir, verbose=args.verbose)
    if not ok:
        sys.exit(2)


if __name__ == '__main__':
    main()
