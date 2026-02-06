#!/usr/bin/env python3
"""
Attempt to parse FIT using `fitdecode`, printing progress and first error.

Usage:
  python fit_try_fitdecode.py path/to/file.fit

Install:
  python -m pip install --user fitdecode
"""
import sys

try:
    import fitdecode
except Exception:
    print('fitdecode not installed. Run: python -m pip install --user fitdecode', file=sys.stderr)
    sys.exit(2)


def main(path):
    print('Using fitdecode to parse:', path)
    try:
        with fitdecode.FitReader(path) as fr:
            for i, msg in enumerate(fr):
                try:
                    if hasattr(msg, 'name'):
                        print(f'{i}: {msg.name}')
                    else:
                        print(f'{i}: {type(msg)}')
                except Exception as e:
                    print('Error printing message', i, e)
    except Exception as e:
        import traceback
        print('fitdecode raised:', e)
        traceback.print_exc()


if __name__ == '__main__':
    if len(sys.argv) < 2:
        print('Usage: fit_try_fitdecode.py file.fit')
        sys.exit(1)
    main(sys.argv[1])
