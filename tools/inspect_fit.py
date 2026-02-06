#!/usr/bin/env python3
import sys
from collections import Counter

try:
    from fitparse import FitFile
except Exception as e:
    print('Fitparse not installed:', e)
    print('Run `pip install fitparse` and re-run this script')
    sys.exit(2)


def print_counts(fit):
    counts = Counter()
    for msg in fit.get_messages():
        counts[msg.name] += 1
    print('Message counts:')
    for k, v in counts.items():
        print(f'  {k}: {v}')


def print_examples(fit, name, limit=5):
    msgs = list(fit.get_messages(name, as_dict=True))
    if not msgs:
        return
    print(f"\nFirst {min(limit,len(msgs))} '{name}' messages:")
    for i, m in enumerate(msgs[:limit], 1):
        print(f'--- {name} #{i} ---')
        for field, value in m.items():
            print(f'  {field}: {value}')


def main(path):
    print('Inspecting:', path)
    try:
        fit = FitFile(path)
    except Exception as e:
        print('Failed to open FIT file:', e)
        return

    try:
        # Count message types
        print_counts(fit)

        # Show examples of common messages
        for n in ('file_id', 'session', 'lap', 'record', 'event', 'device_info'):
            print_examples(fit, n, limit=5)

        # Show developer fields presence
        dev_msgs = list(fit.get_messages('developer_data_id', as_dict=True))
        print(f"\nDeveloper data id messages: {len(dev_msgs)}")
        for i, m in enumerate(dev_msgs[:5], 1):
            print(f'  dev#{i}:', m)

    except Exception as e:
        print('Error while parsing messages:', e)


if __name__ == '__main__':
    if len(sys.argv) < 2:
        print('Usage: inspect_fit.py <file.fit>')
        sys.exit(1)
    main(sys.argv[1])
